//! OS Memory Paginator
//!
//! Abstracción del sistema operativo para paginación dinámica.
//! Utiliza `madvise` en Linux/Android y APIs de Memoria Virtual en Windows.
//! Ahora soporta page size dinámico en lugar de asumir 4096 bytes.

use crate::memory_engine::gguf_layout::ByteRange;
use std::ffi::c_void;
use std::path::Path;

fn align_down(val: usize, align: usize) -> usize {
    val & !(align - 1)
}

fn align_up(val: usize, align: usize) -> usize {
    (val + align - 1) & !(align - 1)
}

/// Patrones de acceso a memoria para madvise
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AccessPattern {
    /// Lectura secuencial continua (optimiza prefetch)
    Sequential,
    /// Acceso aleatorio no predecible
    Random,
    /// Patrón de acceso estándar por defecto del sistema
    Normal,
}

pub struct OSMemoryPaginator {
    mmap_ptr: *mut u8,
    mmap_size: usize,
    page_size: usize,
}

// SAFETY: OSMemoryPaginator owns its raw pointer exclusively and can be
// moved between threads safely. The pointer is never aliased — only one
// OSMemoryPaginator exists per mmap region, and the region is unmapped
// when the paginator is dropped.
//
// Sync is now implemented for async prefetch use cases. Callers must ensure
// that concurrent madvise() calls from multiple threads do not operate on
// overlapping page ranges, which would cause undefined behavior at the
// kernel level. The async prefetch manager serializes access using semaphores.
unsafe impl Send for OSMemoryPaginator {}
unsafe impl Sync for OSMemoryPaginator {}

impl OSMemoryPaginator {
    /// Inicializa el paginador con el puntero base y tamaño del mmap
    /// Usa detección automática de page size del sistema
    pub fn new(mmap_ptr: *mut c_void, mmap_size: usize) -> Self {
        let page_size = Self::detect_page_size();
        Self {
            mmap_ptr: mmap_ptr as *mut u8,
            mmap_size,
            page_size,
        }
    }

    /// Inicializa el paginador con un page size específico
    pub fn with_page_size(mmap_ptr: *mut c_void, mmap_size: usize, page_size: usize) -> Self {
        Self {
            mmap_ptr: mmap_ptr as *mut u8,
            mmap_size,
            page_size,
        }
    }

    /// Detecta el page size del sistema
    fn detect_page_size() -> usize {
        #[cfg(unix)]
        {
            let page_size = unsafe { libc::sysconf(libc::_SC_PAGESIZE) as usize };
            if page_size > 0 {
                return page_size;
            }
        }
        
        #[cfg(windows)]
        {
            use windows_sys::Win32::System::SystemInformation::GetSystemInfo;
            let mut sys_info = unsafe { std::mem::zeroed() };
            unsafe { GetSystemInfo(&mut sys_info) };
            let page_size = sys_info.dwPageSize as usize;
            if page_size > 0 {
                return page_size;
            }
        }
        
        // Fallback a 4KB
        4096
    }

    /// Retorna el page size actual
    pub fn page_size(&self) -> usize {
        self.page_size
    }

    /// Fuerza al sistema operativo a cargar el rango de bytes a RAM (Prefetch).
    /// El rango no necesita estar alineado; esta función lo alinea a PAGE_SIZE.
    pub fn prefetch_range(&self, range: &ByteRange) -> Result<(), std::io::Error> {
        let (ptr, len) = self.get_aligned_ptr_and_len(range)?;
        if len == 0 {
            return Ok(());
        }

        #[cfg(unix)]
        {
            let res = unsafe { libc::madvise(ptr, len, libc::MADV_WILLNEED) };
            if res != 0 {
                return Err(std::io::Error::last_os_error());
            }
        }

        #[cfg(windows)]
        {
            use windows_sys::Win32::System::Memory::{
                PrefetchVirtualMemory, WIN32_MEMORY_RANGE_ENTRY,
            };

            let mut entries = [WIN32_MEMORY_RANGE_ENTRY {
                VirtualAddress: ptr,
                NumberOfBytes: len,
            }];

            // The pseudo-handle for the current process is -1
            let current_process = -1isize as _;

            let res = unsafe { PrefetchVirtualMemory(current_process, 1, entries.as_mut_ptr(), 0) };

            if res == 0 {
                // 0 indicates failure in PrefetchVirtualMemory
                return Err(std::io::Error::last_os_error());
            }
        }

        Ok(())
    }

    /// Marca el rango como libre (`MADV_FREE` en Linux, cae en `evict_range` en Windows/kernels antiguos).
    /// `MADV_FREE` le indica al kernel que puede reutilizar las páginas si hay presión de memoria,
    /// evitando I/O hasta que el kernel realmente las necesite.
    #[allow(unused_variables)] // `ptr` only used inside Linux cfg block
    pub fn mark_as_free(&self, range: &ByteRange) -> Result<(), std::io::Error> {
        let (ptr, len) = self.get_aligned_ptr_and_len(range)?;
        if len == 0 {
            return Ok(());
        }

        #[cfg(any(target_os = "linux", target_os = "android"))]
        {
            #[cfg(target_os = "linux")]
            let advice = libc::MADV_FREE;
            // libc no expone MADV_FREE en bionic (Android); usar el valor
            // crudo del ABI (8) — estable en todo kernel Linux ≥ 4.5.
            #[cfg(target_os = "android")]
            let advice = 8;

            let res = unsafe { libc::madvise(ptr, len, advice) };
            if res != 0 {
                // Si MADV_FREE falla (e.g. kernel < 4.5), caer a MADV_DONTNEED
                unsafe { libc::madvise(ptr, len, libc::MADV_DONTNEED) };
            }
            Ok(())
        }

        #[cfg(not(any(target_os = "linux", target_os = "android")))]
        {
            self.evict_range(range)
        }
    }

    /// Establece el patrón de acceso al kernel (e.g. `MADV_SEQUENTIAL` para prefetching secuencial de capas).
    pub fn set_access_pattern(
        &self,
        range: &ByteRange,
        pattern: AccessPattern,
    ) -> Result<(), std::io::Error> {
        let (ptr, len) = self.get_aligned_ptr_and_len(range)?;
        if len == 0 {
            return Ok(());
        }

        #[cfg(unix)]
        {
            let advice = match pattern {
                AccessPattern::Sequential => libc::MADV_SEQUENTIAL,
                AccessPattern::Random => libc::MADV_RANDOM,
                AccessPattern::Normal => libc::MADV_NORMAL,
            };
            let res = unsafe { libc::madvise(ptr, len, advice) };
            if res != 0 {
                return Err(std::io::Error::last_os_error());
            }
        }

        #[cfg(windows)]
        {
            let _ = (ptr, len, pattern);
        }

        Ok(())
    }

    /// Habilita Huge Pages (`MADV_HUGEPAGE`) para reducir overhead de TLB/page table.
    pub fn mark_hugepages(&self, range: &ByteRange) -> Result<(), std::io::Error> {
        let (ptr, len) = self.get_aligned_ptr_and_len(range)?;
        if len == 0 {
            return Ok(());
        }

        #[cfg(any(target_os = "linux", target_os = "android"))]
        {
            #[cfg(target_env = "gnu")]
            unsafe {
                libc::madvise(ptr, len, libc::MADV_HUGEPAGE);
            }
            #[cfg(not(target_env = "gnu"))]
            let _ = (ptr, len);
        }

        #[cfg(not(any(target_os = "linux", target_os = "android")))]
        {
            let _ = (ptr, len);
        }

        Ok(())
    }

    /// Fuerza al sistema operativo a descartar de RAM el rango de bytes (Evict).
    /// El sistema puede usar esta memoria para otros procesos.
    pub fn evict_range(&self, range: &ByteRange) -> Result<(), std::io::Error> {
        let (ptr, len) = self.get_aligned_ptr_and_len(range)?;
        if len == 0 {
            return Ok(());
        }

        #[cfg(unix)]
        {
            // MADV_DONTNEED: Indica que la memoria no será necesaria en el futuro cercano.
            // Esto permite que el SO libere las páginas físicas.
            let res = unsafe { libc::madvise(ptr, len, libc::MADV_DONTNEED) };
            if res != 0 {
                return Err(std::io::Error::last_os_error());
            }
        }

        #[cfg(windows)]
        {
            use windows_sys::Win32::System::Memory::VirtualUnlock;

            // En Windows, VirtualUnlock saca el rango del working set de la aplicación,
            // lo que es el análogo más cercano a madvise(MADV_DONTNEED) sin destruir el mapeo de archivo (mmap).
            // NOTA: Si el rango no estaba "locked", VirtualUnlock falla con ERROR_NOT_LOCKED.
            // Para archivos mapeados en memoria, es una aproximación.
            unsafe {
                VirtualUnlock(ptr, len);
                // Ignoramos el error ya que puede no haber estado bloqueada en primer lugar
            }
        }

        Ok(())
    }

    /// Libera agresivamente la residencia del rango mapeado COMPLETO.
    ///
    /// `MADV_DONTNEED` sobre todo el mmap: el kernel descarta las páginas
    /// físicas de inmediato (a diferencia de `MADV_FREE`, que las mantiene
    /// en page cache). Se usa en el unload del modelo, ANTES de `munmap`,
    /// para que la memoria vuelva al sistema sin esperar presión.
    ///
    /// Es un hint: el resultado se reporta como telemetría, no como
    /// garantía. Algunos kernels pueden no liberar todo de inmediato.
    pub fn release_all(&self) -> Result<(), std::io::Error> {
        if self.mmap_size == 0 || self.mmap_ptr.is_null() {
            return Ok(());
        }

        #[cfg(unix)]
        {
            let res = unsafe { libc::madvise(self.mmap_ptr as *mut c_void, self.mmap_size, libc::MADV_DONTNEED) };
            if res != 0 {
                return Err(std::io::Error::last_os_error());
            }
        }

        #[cfg(windows)]
        {
            use windows_sys::Win32::System::Memory::VirtualUnlock;
            // Aproximación en Windows: saca el rango del working set.
            // Puede fallar con ERROR_NOT_LOCKED si las páginas nunca
            // estuvieron locked — es un hint, no un error fatal.
            unsafe {
                VirtualUnlock(self.mmap_ptr as *mut c_void, self.mmap_size);
            }
        }

        Ok(())
    }

    /// Obtiene puntero y longitud alineados a los límites de página
    fn get_aligned_ptr_and_len(
        &self,
        range: &ByteRange,
    ) -> Result<(*mut c_void, usize), std::io::Error> {
        if range.start >= self.mmap_size {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "Range start is out of bounds",
            ));
        }

        let start = align_down(range.start, self.page_size);
        // Asegurar no exceder el tamaño total
        let end = align_up(range.end.min(self.mmap_size), self.page_size);

        if start >= end {
            return Ok((std::ptr::null_mut(), 0));
        }

        let len = end - start;
        let ptr = unsafe { self.mmap_ptr.add(start) };

        Ok((ptr as *mut c_void, len))
    }
}

/// Pista al kernel para descartar el page cache asociado a un archivo.
///
/// `posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED)` — se llama DESPUÉS del
/// `munmap`/`llama_free_model`, cuando el archivo ya no está mapeado.
/// Hint puro: algunos filesystems devuelven EINVAL y eso se tolera como
/// warning, no como error. En Windows es no-op (sin equivalente directo).
pub fn release_file_cache(path: &Path) -> std::io::Result<()> {
    #[cfg(any(target_os = "linux", target_os = "android"))]
    {
        use std::os::fd::AsRawFd;

        let file = std::fs::File::open(path)?;
        let res = unsafe {
            libc::posix_fadvise(
                file.as_raw_fd(),
                0,
                0,
                libc::POSIX_FADV_DONTNEED,
            )
        };
        if res != 0 {
            return Err(std::io::Error::last_os_error());
        }
    }

    #[cfg(not(any(target_os = "linux", target_os = "android")))]
    {
        let _ = path;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_align_page_size() {
        let page_size = 4096;
        assert_eq!(align_down(4095, page_size), 0);
        assert_eq!(align_down(4096, page_size), 4096);
        assert_eq!(align_down(4097, page_size), 4096);

        assert_eq!(align_up(4095, page_size), 4096);
        assert_eq!(align_up(4096, page_size), 4096);
        assert_eq!(align_up(4097, page_size), 8192);
    }

    #[test]
    fn test_aligned_ptr_and_len() {
        // Dummy pointer
        let dummy_ptr = 8192 as *mut c_void;
        let paginator = OSMemoryPaginator::new(dummy_ptr, 100000);

        let range = ByteRange {
            start: 5000,
            end: 15000,
        };
        let (ptr, len) = paginator.get_aligned_ptr_and_len(&range).unwrap();

        // 5000 is page 1 (starts at 4096).
        let expected_start = 4096;
        // 15000 ends at page 3 (12288 -> 16384).
        let expected_end = 16384;

        // Ptr must be dummy_ptr + expected_start
        assert_eq!(ptr, (8192 + expected_start) as *mut c_void);
        assert_eq!(len, expected_end - expected_start);
    }

    #[test]
    fn test_dynamic_page_size() {
        let dummy_ptr = 8192 as *mut c_void;
        let paginator = OSMemoryPaginator::new(dummy_ptr, 100000);
        
        // Page size should be detected and be reasonable
        assert!(paginator.page_size() >= 4096);
        assert!(paginator.page_size() <= 65536);
        assert!(paginator.page_size() & (paginator.page_size() - 1) == 0); // Power of 2
    }

    #[test]
    fn test_custom_page_size() {
        let dummy_ptr = 8192 as *mut c_void;
        let custom_page_size = 8192;
        let paginator = OSMemoryPaginator::with_page_size(dummy_ptr, 100000, custom_page_size);
        
        assert_eq!(paginator.page_size(), custom_page_size);
    }
}
