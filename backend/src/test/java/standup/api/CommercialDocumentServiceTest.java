package standup.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.text.PDFTextStripper;
import org.junit.jupiter.api.Test;

class CommercialDocumentServiceTest {
    private final CommercialDocumentService service = new CommercialDocumentService();

    @Test
    void offerIsReadableAndIncludesCompanyStandPriceAndDraftDisclaimers() throws IOException {
        byte[] pdf = service.offer(
                Map.ofEntries(
                        Map.entry("edizione", 2026),
                        Map.entry("id_espositore", "EX-TEST"),
                        Map.entry("ragione_sociale", "Arcade Test S.r.l."),
                        Map.entry("partita_iva", "IT12345678901"),
                        Map.entry("citta", "Milano"),
                        Map.entry("referente", "Ada Test"),
                        Map.entry("email_referente", "ada@example.invalid"),
                        Map.entry("codice_stand", "A-12"),
                        Map.entry("padiglione", "A"),
                        Map.entry("superficie_mq", new BigDecimal("18.00")),
                        Map.entry("pacchetto", "PREMIUM"),
                        Map.entry("stato", "BOZZA"),
                        Map.entry("sconto_percentuale", new BigDecimal("5.00")),
                        Map.entry("imponibile_listino_eur", new BigDecimal("1000.00")),
                        Map.entry("totale_eur", new BigDecimal("950.00")),
                        Map.entry("acconti_eur", BigDecimal.ZERO)),
                List.of(Map.of(
                        "codice_voce", "SPAZIO-A",
                        "descrizione", "Spazio espositivo",
                        "quantita", new BigDecimal("18.00"),
                        "prezzo_unitario_eur", new BigDecimal("55.56"),
                        "importo_eur", new BigDecimal("1000.00"))),
                "Condizioni da concordare con il team commerciale.");

        try (var document = Loader.loadPDF(pdf)) {
            String text = new PDFTextStripper().getText(document);
            assertEquals(1, document.getNumberOfPages());
            assertTrue(text.contains("ARCADE MILANO"));
            assertTrue(text.contains("Arcade Test S.r.l."));
            assertTrue(text.contains("IT12345678901"));
            assertTrue(text.contains("A-12"));
            assertTrue(text.contains("950.00 EUR"));
            assertTrue(text.contains("Condizioni da concordare"));
            assertTrue(text.contains("non fiscale"));
            assertTrue(text.contains("Firma espositore"));
        }
    }

    @Test
    void contractSummaryClearlyStatesItIsNotTheSignedOriginal() throws IOException {
        byte[] pdf = service.contractSummary(
                Map.of("edizione", 2026, "stato", "FIRMATA", "firmata_il", "2026-11-08T10:00:00Z"),
                List.of(),
                List.of());

        try (var document = Loader.loadPDF(pdf)) {
            String text = new PDFTextStripper().getText(document).toLowerCase(java.util.Locale.ROOT).replaceAll("\\s+", " ");
            assertTrue(text.contains("riepilogo contrattuale"));
            assertTrue(text.contains("firma registrata"));
            assertTrue(text.contains("non contiene una firma elettronica"));
            assertTrue(text.contains("firma espositore"));
        }
    }
}
