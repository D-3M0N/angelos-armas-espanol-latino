// F17: decompila las funciones que llaman a las API de la variable APIS. Salida a cache/; no se commitea.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.listing.*;
import java.util.*;

public class DecompActiveWnd extends GhidraScript {
    public void run() throws Exception {
        Set<String> want = new HashSet<>(Arrays.asList(System.getenv("APIS").split(",")));
        FunctionManager fm = currentProgram.getFunctionManager();
        DecompInterface di = new DecompInterface(); di.openProgram(currentProgram);
        Set<Function> fs = new LinkedHashSet<>();
        for (Symbol s : currentProgram.getSymbolTable().getAllSymbols(true)) {
            if (!want.contains(s.getName())) continue;
            for (Reference r : getReferencesTo(s.getAddress())) {
                Function f = fm.getFunctionContaining(r.getFromAddress());
                println("XREF " + s.getName() + " " + r.getFromAddress() + " in " + (f==null?"?":f.getEntryPoint()));
                if (f != null) fs.add(f);
            }
        }
        for (Function f : fs) {
            DecompileResults r = di.decompileFunction(f, 90, monitor);
            println("=== " + f.getEntryPoint() + " " + f.getName());
            println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "FALLO");
        }
    }
}
