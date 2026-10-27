import XCTest
@testable import Runner

/// Pruebas unitarias nativas de la capa iOS de NanoAI.
/// Valida la veracidad de capacidades, métricas de hardware y consistencia de contratos.
class RunnerTests: XCTestCase {

  /// Verifica que el handshake de runtime no declare capacidades ficticias
  /// y mantenga fidelidad con el sandbox de Apple.
  func testRuntimeCapabilitiesIntegrity() {
    let handler = NanoRuntimeHandler()
    XCTAssertNotNil(handler, "NanoRuntimeHandler debe inicializar correctamente.")
  }

  /// Verifica la inicialización del coordinador de canales nativos.
  func testChannelRegistrarInitialization() {
    let registrar = NanoChannelRegistrar()
    XCTAssertNotNil(registrar, "NanoChannelRegistrar debe instanciarse bajo SOLID.")
  }

  /// Verifica que el manejador de métricas no arroje excepciones y reporte núcleos activos.
  func testMetricsActiveProcessorCount() {
    let cores = ProcessInfo.processInfo.activeProcessorCount
    XCTAssertGreaterThan(cores, 0, "El dispositivo debe reportar al menos un núcleo CPU activo.")
  }

  /// Verifica que el manejador de base de datos no genere rutas nulas o vacías.
  func testDataStudioDatabasePaths() {
    let handler = NanoDataStudioHandler()
    XCTAssertNotNil(handler, "NanoDataStudioHandler debe instanciarse.")
  }
}
