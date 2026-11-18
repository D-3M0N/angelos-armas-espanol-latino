// F2: busca cadenas C cortas (STR=a,b,c) en memoria y lista sus xrefs. Solo direcciones.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.address.*;
import java.util.*;

public class XrefsCadena extends GhidraScript {
    public void run() throws Exception {
        FunctionManager fm = currentProgram.getFunctionManager();
        for (String s : System.getenv("STR").split(",")) {
            byte[] pat = (s + "\0").getBytes("US-ASCII");
            byte[] mask = new byte[pat.length]; Arrays.fill(mask, (byte) 0xff);
            Address a = currentProgram.getMinAddress();
            while (a != null) {
                Address f = currentProgram.getMemory().findBytes(a, pat, mask, true, monitor);
                if (f == null) break;
                // solo cadenas que empiezan en frontera (byte previo 0)
                byte prev = currentProgram.getMemory().getByte(f.subtract(1));
                List<String> out = new ArrayList<>();
                for (Reference r : getReferencesTo(f)) {
                    Function fn = fm.getFunctionContaining(r.getFromAddress());
                    out.add(r.getFromAddress() + "@" + (fn == null ? "?" : fn.getEntryPoint()));
                }
                if (prev == 0) println("STR \"" + s + "\" " + f + " " + out);
                a = f.add(1);
            }
        }
    }
}
