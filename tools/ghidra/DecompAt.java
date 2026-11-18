// F17: decompila las funciones en las direcciones de ADDRS (hex separadas por coma). Salida a cache/; no se commitea.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;

public class DecompAt extends GhidraScript {
    public void run() throws Exception {
        DecompInterface di = new DecompInterface(); di.openProgram(currentProgram);
        for (String a : System.getenv("ADDRS").split(",")) {
            Function f = getFunctionContaining(toAddr(a));
            if (f == null && System.getenv("CREAR") != null) { disassemble(toAddr(a)); f = createFunction(toAddr(a), null); }
            if (f == null) { println("=== " + a + " sin funcion"); continue; }
            DecompileResults r = di.decompileFunction(f, 90, monitor);
            println("=== " + f.getEntryPoint() + " " + f.getName());
            println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "FALLO");
        }
    }
}
