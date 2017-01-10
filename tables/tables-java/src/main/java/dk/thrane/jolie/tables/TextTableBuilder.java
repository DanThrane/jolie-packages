package dk.thrane.jolie.tables;

import java.util.*;
import java.util.stream.Collectors;

public class TextTableBuilder {
    private List<List<String>> rows = new ArrayList<>();

    public void addRow(List<?> cols) {
        try {
            rows.add(cols.stream().map(Object::toString).collect(Collectors.toList()));
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private int[] colWidths() {
        int cols = rows.stream().mapToInt(List::size).max().orElse(0);
        int[] widths = new int[cols];
        for (int colNum = 0; colNum < cols; colNum++) {
            int finalColNum = colNum;
            widths[colNum] = rows.stream().mapToInt(it -> it
                    .size() > finalColNum ? it.get(finalColNum).length() : 0
            ).max().orElse(0) + 2;
        }
        return widths;
    }

    @Override
    public String toString() {
        StringBuilder buf = new StringBuilder();
        int[] colWidths = colWidths();

        for (List<String> row : rows) {
            for (int colNum = 0; colNum < row.size(); colNum++) {
                buf.append(padRight(row.get(colNum), colWidths[colNum]));
                buf.append(' ');
            }

            buf.append('\n');
        }
        return buf.toString();
    }

    private String padRight(String s, int n) {
        return String.format("%1$-" + n + "s", s);
    }
}
