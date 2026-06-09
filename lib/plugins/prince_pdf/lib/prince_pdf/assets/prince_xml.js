/**
 * PrinceXML DOM preprocessing for LCMS Core.
 *
 * Runs inside Prince's controlled JS environment via the --script flag.
 * This file is intentionally minimal — handles the universally useful
 * cleanups, leaves template-specific behaviors to forks.
 *
 * Problem solved here: CSS :empty does not match elements containing
 * only whitespace text or empty inline children. Such paragraphs leak
 * into the tagged PDF as P elements, producing accessibility noise
 * (screen readers announce them).
 *
 * Solution: tag whitespace-only paragraphs with a class that
 * prince_xml.css then maps to Artifact.
 *
 * Reference: https://www.princexml.com/doc/javascript/
 */
document.addEventListener('DOMContentLoaded', function() {
  markEffectivelyEmptyParagraphs();
});

/**
 * Adds .pdf-artifact to <p> elements containing no non-whitespace content.
 * Matches <p></p>, <p>   </p>, <p><span></span></p>, etc.
 */
function markEffectivelyEmptyParagraphs() {
  var paragraphs = document.getElementsByTagName('p');

  for (var i = 0; i < paragraphs.length; i++) {
    var p = paragraphs[i];
    var text = (p.textContent || '').trim();

    if (text === '') {
      p.classList.add('pdf-artifact');
    }
  }
}
