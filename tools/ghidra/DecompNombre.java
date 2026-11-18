// Decompila funciones por nombre de simbolo (NOMBRES=a,b; coincidencia por subcadena). Salida a cache/; no se commitea.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;

public class DecompNombre extends GhidraScript {
    public void run() throws Exception {
        DecompInterface di = new DecompInterface(); di.openProgram(currentProgram);
        for (String n : System.getenv("NOMBRES").split(",")) {
            for (Symbol s : currentProgram.getSymbolTable().getAllSymbols(true)) {
                if (!s.getName().contains(n)) continue;
                Function f = getFunctionContaining(s.getAddress());
                if (f == null) { disassemble(s.getAddress()); f = createFunction(s.getAddress(), null); }
                if (f == null) continue;
                DecompileResults r = di.decompileFunction(f, 90, monitor);
                println("=== " + s.getName() + " @ " + f.getEntryPoint());
                println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "FALLO");
            }
        }
    }
}
