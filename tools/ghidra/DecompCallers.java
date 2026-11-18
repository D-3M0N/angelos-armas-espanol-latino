// F17: decompila las funciones que llaman a la direccion de la variable ADDR (hex). Salida a cache/; no se commitea.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.listing.*;
import java.util.*;

public class DecompCallers extends GhidraScript {
    public void run() throws Exception {
        FunctionManager fm = currentProgram.getFunctionManager();
        DecompInterface di = new DecompInterface(); di.openProgram(currentProgram);
        Set<Function> fs = new LinkedHashSet<>();
        for (Reference r : getReferencesTo(toAddr(System.getenv("ADDR")))) {
            Function f = fm.getFunctionContaining(r.getFromAddress());
            println("XREF " + r.getFromAddress() + " in " + (f==null?"?":f.getEntryPoint()));
            if (f != null) fs.add(f);
        }
        for (Function f : fs) {
            DecompileResults r = di.decompileFunction(f, 90, monitor);
            println("=== " + f.getEntryPoint() + " " + f.getName());
            println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "FALLO");
        }
    }
}
