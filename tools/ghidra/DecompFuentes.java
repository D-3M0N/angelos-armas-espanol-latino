// B.9: decompila las funciones de fuente/glifo. Salida a stdout (redirigir a cache/); no se commitea.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;

public class DecompFuentes extends GhidraScript {
    public void run() throws Exception {
        String[] addrs = {"004128b0","0040aff0","004126a0","004127b0","00412a30","00412ba0","00412c20","0040f770"};
        DecompInterface di = new DecompInterface();
        di.openProgram(currentProgram);
        for (String a : addrs) {
            Function f = getFunctionAt(toAddr(a));
            if (f == null) { println("NOFUNC " + a); continue; }
            DecompileResults r = di.decompileFunction(f, 60, monitor);
            println("=== " + a + " " + f.getName());
            println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "FALLO");
        }
    }
}
