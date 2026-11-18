// B.8: xrefs a las API de texto. Solo direcciones y nombre de función; sin cadenas del juego.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.symbol.*;
import ghidra.program.model.listing.*;
import java.util.*;

public class XrefsTexto extends GhidraScript {
    public void run() throws Exception {
        Set<String> want = new HashSet<>(Arrays.asList("TextOutA","ExtTextOutA","GetGlyphOutlineA","DrawTextA","DrawTextExA",
            "CreateFontA","CreateFontIndirectA","GetTextExtentPoint32A","GetTextMetricsA","IsDBCSLeadByte","IsDBCSLeadByteEx",
            "MultiByteToWideChar","CharNextA","lstrlenA","GetACP","GetOEMCP","GetDriveTypeA","GetVolumeInformationA"));
        SymbolTable st = currentProgram.getSymbolTable();
        FunctionManager fm = currentProgram.getFunctionManager();
        for (Symbol s : st.getAllSymbols(true)) {
            if (!want.contains(s.getName())) continue;
            if (s.getSymbolType() != SymbolType.FUNCTION && s.getSymbolType() != SymbolType.LABEL) continue;
            List<String> out = new ArrayList<>();
            for (Reference r : getReferencesTo(s.getAddress())) {
                Function f = fm.getFunctionContaining(r.getFromAddress());
                out.add(r.getFromAddress() + "@" + (f == null ? "?" : f.getEntryPoint()));
            }
            println("XREF " + s.getName() + " (" + s.getAddress() + ") n=" + out.size() + " " + out);
        }
    }
}
