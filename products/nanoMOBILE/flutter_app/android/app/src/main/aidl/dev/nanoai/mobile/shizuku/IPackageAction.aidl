// A14.4 — UserService de Shizuku. El código de ESTE servicio corre en el
// proceso con privilegios de Shizuku (uid shell) cuando la app lo vincula vía
// Shizuku.bindUserService. Solo expone operaciones TIPADAS de bajo riesgo.
// NUNCA se acepta un comando libre: solo packageName (validado en el llamador).
package dev.nanoai.mobile.shizuku;

interface IPackageAction {
    // Detiene una app (reversible reabriéndola). Devuelve true si se solicitó.
    boolean forceStop(String packageName);

    // Consulta el estado de un paquete con privilegios.
    String queryPackage(String packageName);
}
