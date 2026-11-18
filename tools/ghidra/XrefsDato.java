// F17: xrefs a una direccion (variable DATO) y decompilacion de las funciones que la escriben. Salida a cache/.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.listing.*;
import java.util.*;

public class XrefsDato extends GhidraScript {
    public void run() throws Exception {
        FunctionManager fm = currentProgram.getFunctionManager();
        DecompInterface di = new DecompInterface(); di.openProgram(currentProgram);
        Set<Function> fs = new LinkedHashSet<>();
        for (Reference r : getReferencesTo(toAddr(System.getenv("DATO")))) {
            Function f = fm.getFunctionContaining(r.getFromAddress());
            println("XREF " + r.getReferenceType() + " " + r.getFromAddress() + " in " + (f==null?"?":f.getEntryPoint()));
            if (f != null && r.getReferenceType().isWrite()) fs.add(f);
        }
        for (Function f : fs) {
            DecompileResults r = di.decompileFunction(f, 90, monitor);
            println("=== " + f.getEntryPoint());
            println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "FALLO");
        }
    }
}
