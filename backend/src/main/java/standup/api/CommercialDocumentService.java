package standup.api;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.text.Normalizer;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.springframework.stereotype.Component;

/** Creates compact PDF offers and informational contract summaries from saved commercial facts. */
@Component
public class CommercialDocumentService {
    private static final float MARGIN = 48;
    private static final float CONTENT_WIDTH = PDRectangle.A4.getWidth() - (MARGIN * 2);
    private static final Color COFFEE_BEAN = new Color(0x17, 0x12, 0x19);
    private static final Color LIME_CREAM = new Color(0xcb, 0xff, 0x8c);
    private static final Color JUNGLE_TEAL = new Color(0x3f, 0x82, 0x6d);
    private static final Color GHOST_WHITE = new Color(0xf7, 0xf7, 0xff);
    private static final PDType1Font REGULAR = new PDType1Font(Standard14Fonts.FontName.HELVETICA);
    private static final PDType1Font BOLD = new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD);

    public byte[] offer(Map<String, Object> facts, List<Map<String, Object>> lines) {
        return offer(facts, lines, null);
    }

    public byte[] offer(Map<String, Object> facts, List<Map<String, Object>> lines, String notes) {
        return render("OFFERTA COMMERCIALE - BOZZA", facts, lines, List.of(), false, notes);
    }

    public byte[] contractSummary(
            Map<String, Object> facts,
            List<Map<String, Object>> lines,
            List<Map<String, Object>> payments) {
        return render("RIEPILOGO CONTRATTUALE", facts, lines, payments, true, null);
    }

    private byte[] render(
            String title,
            Map<String, Object> facts,
            List<Map<String, Object>> lines,
            List<Map<String, Object>> payments,
            boolean signedSummary,
            String notes) {
        try (PDDocument document = new PDDocument(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            PageWriter page = new PageWriter(document, title);
            page.line("ARCADE MILANO  |  STAND UP", BOLD, 10, JUNGLE_TEAL);
            page.gap(13);
            page.line(title, BOLD, 18, COFFEE_BEAN);
            page.line("Edizione " + value(facts, "edizione") + "    Emesso il " + ZonedDateTime.now(ZoneId.of("Europe/Rome")).format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")), REGULAR, 9, COFFEE_BEAN);
            page.gap(10);

            page.section("ESPOSITORE");
            page.wrapped("Ragione sociale: " + valueOr(facts, "ragioneSociale", "DA COMPLETARE"), BOLD);
            page.wrapped("Riferimento interno: " + value(facts, "idEspositore"), REGULAR);
            page.wrapped("Partita IVA: " + valueOr(facts, "partitaIva", "DA COMPLETARE"), REGULAR);
            page.wrapped("Citta: " + valueOr(facts, "citta", "DA COMPLETARE"), REGULAR);
            page.wrapped("Referente: " + valueOr(facts, "referente", "DA COMPLETARE"), REGULAR);
            page.wrapped("Email referente: " + valueOr(facts, "emailReferente", "DA COMPLETARE"), REGULAR);
            page.gap(6);

            page.section("SPAZIO E PARTECIPAZIONE");
            page.wrapped("Stand: " + valueOr(facts, "codiceStand", "DA ASSEGNARE") + "   |   Padiglione: " + valueOr(facts, "padiglione", "DA CONFERMARE"), REGULAR);
            page.wrapped("Superficie: " + decimal(get(facts, "superficieMq")) + " m2   |   Pacchetto: " + valueOr(facts, "pacchetto", "NON DICHIARATO"), REGULAR);
            page.wrapped("Stato pratica: " + valueOr(facts, "stato", "BOZZA") + (signedSummary ? "   |   Firma registrata: " + valueOr(facts, "firmataIl", "data non disponibile") : ""), REGULAR);
            page.gap(8);

            page.section("VOCI ECONOMICHE");
            page.line("Descrizione", BOLD, 9, COFFEE_BEAN);
            page.line("Quantita     Prezzo unitario      Importo", BOLD, 9, COFFEE_BEAN);
            page.gap(2);
            for (Map<String, Object> item : lines) {
                page.wrapped(valueOr(item, "descrizione", value(item, "codiceVoce")), BOLD);
                page.wrapped("Codice " + value(item, "codiceVoce") + "   " + decimal(get(item, "quantita"))
                        + "   " + money(get(item, "prezzoUnitarioEur")) + "   " + money(get(item, "importoEur")), REGULAR);
            }
            page.gap(6);

            page.section("RIEPILOGO");
            page.wrapped("Imponibile di listino: " + money(get(facts, "imponibileListinoEur")), REGULAR);
            page.wrapped("Sconto dichiarato: " + decimal(get(facts, "scontoPercentuale")) + "%", REGULAR);
            page.wrapped("Totale imponibile: " + money(get(facts, "totaleEur")) + " (IVA esclusa)", BOLD);
            page.wrapped("Acconti registrati: " + money(get(facts, "accontiEur")), REGULAR);
            if (payments.isEmpty()) {
                page.wrapped("Pagamenti registrati in questa pratica: nessuno.", REGULAR);
            } else {
                page.wrapped("Pagamenti registrati:", BOLD);
                for (Map<String, Object> payment : payments) {
                    page.wrapped("- " + value(payment, "ricevutoIl") + "  " + money(get(payment, "importoEur"))
                            + "  Riferimento: " + valueOr(payment, "riferimento", "non dichiarato"), REGULAR);
                }
            }
            page.wrapped("Saldo pagato: non tracciato dal sistema.", REGULAR);
            page.gap(9);

            page.section("NOTE");
            if (notes != null && !notes.isBlank()) page.wrapped("Nota commerciale: " + notes.strip(), REGULAR);
            page.wrapped("Prezzi al netto dell'IVA. Aliquota, scadenze, modalita di pagamento e condizioni complete sono da confermare dall'organizzazione.", REGULAR);
            if (signedSummary) {
                page.wrapped("Documento di riepilogo generato dal sistema. Non contiene una firma elettronica e non sostituisce l'originale sottoscritto.", BOLD);
            } else {
                page.wrapped("Bozza informativa non fiscale, soggetta ad approvazione commerciale. Validita e condizioni economiche da confermare dall'organizzazione.", REGULAR);
            }
            page.gap(12);
            page.line("Firma espositore: ____________________     Firma organizzazione: ____________________", REGULAR, 9, COFFEE_BEAN);

            page.close();
            document.save(output);
            return output.toByteArray();
        } catch (Exception failure) {
            throw new IllegalStateException("Impossibile generare il documento commerciale PDF.", failure);
        }
    }

    private static String value(Map<String, Object> facts, String key) {
        Object value = get(facts, key);
        return value == null || String.valueOf(value).isBlank() ? "Non dichiarato" : String.valueOf(value);
    }

    private static String valueOr(Map<String, Object> facts, String key, String fallback) {
        Object value = get(facts, key);
        return value == null || String.valueOf(value).isBlank() ? fallback : String.valueOf(value);
    }

    private static Object get(Map<String, Object> values, String key) {
        if (values.containsKey(key)) return values.get(key);
        StringBuilder databaseKey = new StringBuilder();
        for (char character : key.toCharArray()) {
            if (Character.isUpperCase(character)) databaseKey.append('_').append(Character.toLowerCase(character));
            else databaseKey.append(character);
        }
        return values.get(databaseKey.toString());
    }

    private static String decimal(Object value) {
        if (value == null) return "Non disponibile";
        try { return new BigDecimal(String.valueOf(value)).stripTrailingZeros().toPlainString(); }
        catch (NumberFormatException ignored) { return String.valueOf(value); }
    }

    private static String money(Object value) {
        if (value == null) return "Non disponibile";
        try { return new BigDecimal(String.valueOf(value)).setScale(2, java.math.RoundingMode.HALF_UP).toPlainString() + " EUR"; }
        catch (NumberFormatException ignored) { return String.valueOf(value); }
    }

    private static String safeText(String value) {
        String normalized = Normalizer.normalize(value, Normalizer.Form.NFKD)
                .replace("€", " EUR")
                .replace("–", "-")
                .replace("—", "-")
                .replace("’", "'")
                .replace("“", "\"")
                .replace("”", "\"");
        return normalized.replaceAll("\\p{M}+", "").replaceAll("[^\\x20-\\xFF]", "?");
    }

    private static final class PageWriter {
        private final PDDocument document;
        private final String title;
        private PDPageContentStream content;
        private float y;

        private PageWriter(PDDocument document, String title) throws Exception {
            this.document = document;
            this.title = title;
            newPage();
        }

        private void newPage() throws Exception {
            if (content != null) content.close();
            PDPage page = new PDPage(PDRectangle.A4);
            document.addPage(page);
            content = new PDPageContentStream(document, page);
            content.setNonStrokingColor(COFFEE_BEAN);
            content.addRect(0, PDRectangle.A4.getHeight() - 46, PDRectangle.A4.getWidth(), 46);
            content.fill();
            content.setNonStrokingColor(LIME_CREAM);
            content.beginText();
            content.setFont(BOLD, 9);
            content.newLineAtOffset(MARGIN, PDRectangle.A4.getHeight() - 29);
            content.showText(safeText(title));
            content.endText();
            y = PDRectangle.A4.getHeight() - 68;
        }

        private void section(String label) throws Exception {
            ensure(25);
            content.setNonStrokingColor(JUNGLE_TEAL);
            content.addRect(MARGIN, y - 3, CONTENT_WIDTH, 18);
            content.fill();
            line(label, BOLD, 9, GHOST_WHITE);
            y -= 22;
        }

        private void line(String text, PDType1Font font, float size, Color color) throws Exception {
            ensure(size + 4);
            content.setNonStrokingColor(color);
            content.beginText();
            content.setFont(font, size);
            content.newLineAtOffset(MARGIN, y);
            content.showText(safeText(text));
            content.endText();
            y -= size + 5;
        }

        private void wrapped(String text, PDType1Font font) throws Exception {
            String safe = safeText(text);
            StringBuilder line = new StringBuilder();
            for (String word : safe.split("\\s+")) {
                String candidate = line.isEmpty() ? word : line + " " + word;
                if (!line.isEmpty() && font.getStringWidth(candidate) * 9 / 1000 > CONTENT_WIDTH) {
                    line(line.toString(), font, 9, COFFEE_BEAN);
                    line.setLength(0);
                    line.append(word);
                } else {
                    if (!line.isEmpty()) line.append(' ');
                    line.append(word);
                }
            }
            if (!line.isEmpty()) line(line.toString(), font, 9, COFFEE_BEAN);
        }

        private void gap(float amount) { y -= amount; }

        private void ensure(float height) throws Exception {
            if (y - height < MARGIN) newPage();
        }

        private void close() throws Exception {
            content.close();
        }
    }
}
