// default page width (letter size with 1in margins),
// content will be export to this width and need to be adjusted
var GOOGLE_PAGE_WIDTH = 468;
// for conversion, 1 Pixel [px] = 0.75 Point [pt]
var PX_TO_PT = 0.75;
// margin for positioned images, setting it as 0 to align images to the right as we can't set margins for images now
// due to the lack of support for this in html/app script/docs api
var IMAGE_MARGIN = 0;
// default font size for elements we're copying
var DEFAULT_FONT_SIZE = 10;
// brand font applied to copied header/footer paragraphs that have no explicit
// font, so they match the Lexend body (keep in sync with $font-family-body in
// app/assets/stylesheets/gdoc.scss)
var BRAND_FONT = 'Lexend';
// Header right-side typography (see styleHeaderRight): the lesson-type line is
// bold and one point larger than the estimated-time line, which is normal
// weight. Keep in sync with the PDF banner (.c-lesson-banner__type / __time in
// app/assets/stylesheets/gdoc.scss).
var HEADER_LESSON_TYPE_SIZE = 12;
var HEADER_ESTIMATED_TIME_SIZE = 11;
// Footer typography (see footerLineStyles): the copyright line is normal weight; the
// course and unit/lesson lines are bold and one point larger. Sizes are set for
// the Gdoc footer per the styling spec (larger than the PDF footer in
// app/assets/stylesheets/pdf_plain.scss).
var FOOTER_COPYRIGHT_SIZE = 11;
var FOOTER_BOLD_SIZE = 12;
// tags
var RE_SIZE = /\[(?:\d+)\]/;

function getParentWidth(parent, defaultWidth) {
  if (parent.getType() == DocumentApp.ElementType.TABLE_CELL) {
    parent = parent.asTableCell();
    let parentWidth = parent.getWidth();
    // if cell is merged from several cells, then we need to calculate the width of all siblings to get the real width
    // otherwise we will get the width of the first cell only
    if (parent.getColSpan() > 1) {
      let colSpan = parent.getColSpan() - 1; // Number of siblings to include
      let nextSibling = parent.getNextSibling();
      while (nextSibling && colSpan > 0) {
        parentWidth += nextSibling.getWidth(); // Add the sibling's width
        nextSibling = nextSibling.getNextSibling(); // Move to the next sibling
        colSpan--; // Decrease the remaining siblings to process
      }
    }
    return parentWidth - parent.getPaddingLeft() - parent.getPaddingRight();
  }
  return defaultWidth;
}

/**
 * Copy elements to new doc
 */
function appendElementToDoc(document, element) {
  var tName = underscoreToCamelCase(element.getType() + '');
  try {
    document['append' + tName](element);
  } catch (err) {
    Logger.log(err + '');
  }
  return document;
}

/**
 * Transform typename to function name
 */
function underscoreToCamelCase(type) {
  type = type.toLowerCase();
  var tName = type.charAt(0).toUpperCase() + type.slice(1);
  var parts = tName.split('_');
  if (parts.length == 2) {
    tName = parts[0] + parts[1].charAt(0).toUpperCase() + parts[1].slice(1);
  }
  return tName;
}

/**
 * Update inlined images
 */
function updateInlinedImages(body, documentWidth) {
  var images = body.getImages();

  for (var i = 0; i < images.length; i++) {
    var img = images[i];
    var parent = img.getParent().getParent();
    var altDescription = img.getAltDescription();
    // check if this is our image, should contain [size] as description
    if (!RE_SIZE.test(altDescription)) continue;
    var parentWidth = getParentWidth(parent, documentWidth);
    var previousWidth = img.getWidth();
    var previousHeight = img.getHeight();
    var newWidth = parentWidth / PX_TO_PT;
    var newHeight = previousHeight * (newWidth / previousWidth);
    img.setWidth(newWidth);
    img.setHeight(newHeight);
    // remove service information from alt description
    img.setAltDescription(altDescription.replace(RE_SIZE, '').trim());
  }
}

/**
 * Update positioned images
 */
function updatePositionedImages(body, documentWidth) {
  var paragraphs = body.getParagraphs();

  for (var childIndex = 0; childIndex < paragraphs.length; childIndex++) {
    var child = paragraphs[childIndex];
    // Collect images from current container
    var images = child.getPositionedImages();
    var parent = child.getParent();
    var parentWidth = 0;
    var newCommulativeWidth = 0;
    var newCommulativeHeight = 0;
    for (var i = 0; i < images.length; i++) {
      var img = images[i];
      var previousWidth = img.getWidth();
      var previousHeight = img.getHeight();
      // there is no way to get alt description or another information for the images
      // we're doing an assumption that we need to adjust only images with width < 100
      if (previousWidth >= 100) continue;
      // not process images if connected paragraph contains $IMG
      if (child.getText().includes('$IMG')) {
        child.replaceText('\\$IMG', '');
        continue;
      }
      // value in pt
      parentWidth = parentWidth || getParentWidth(parent, documentWidth);
      // need value in px, previousWidth is number of percent from parent
      var newWidth = ((parentWidth / PX_TO_PT) * previousWidth) / 100;
      var newHeight = previousHeight * (newWidth / previousWidth);
      img = img.setWidth(newWidth);
      img = img.setHeight(newHeight);
      img = img.setTopOffset(newCommulativeHeight);
      newCommulativeHeight += newHeight;
      newCommulativeWidth += newWidth + IMAGE_MARGIN;
      var offset = img.getLeftOffset();
      // if offset is 0, then image is aligned to the left and we don't need to adjust it
      if (offset !== 0) {
        img.setLeftOffset(parentWidth - newCommulativeWidth * PX_TO_PT);
      }
    }
  }
}

function updateParagraphStyles(elementFrom, elementTo) {
  // adjust font size for first&last paragraphs
  var tmplParagraphs = elementFrom.getParagraphs();
  var documentParagraphs = elementTo.getParagraphs();
  if (tmplParagraphs && documentParagraphs) {
    var diff = documentParagraphs.length - tmplParagraphs.length;
    for (var i = 0; i < diff; i++) {
      documentParagraphs[i].removeFromParent();
    }
    tmplParagraphs.forEach(function (el, idx) {
      if (idx < documentParagraphs.length) {
        var tmplParagraph = tmplParagraphs[idx];
        var documentParagraph = documentParagraphs[idx + diff];
        if (!documentParagraph) return;
        var styles = {};
        var attrs = tmplParagraph.getAttributes();
        // set font size from template or if it's not set, then set DEFAULT_FONT_SIZE unless paragraph contains RE_SIZE
        var fontSize = attrs[DocumentApp.Attribute.FONT_SIZE];
        var text = documentParagraph.getText();
        if (RE_SIZE.test(text)) {
          // get font size from RE_SIZE (e.g. for [12] take 12)
          fontSize = parseInt(text.match(RE_SIZE)[0].replace(/\D/g, ''));
          // remove [font size] from documentParagraph
          documentParagraph.replaceText('\\[.*\\]', '');
        }
        styles[DocumentApp.Attribute.FONT_SIZE] = fontSize || DEFAULT_FONT_SIZE;
        styles[DocumentApp.Attribute.LINE_SPACING] = attrs[DocumentApp.Attribute.LINE_SPACING];
        styles[DocumentApp.Attribute.FONT_FAMILY] =
          attrs[DocumentApp.Attribute.FONT_FAMILY] || BRAND_FONT;
        documentParagraph.setAttributes(styles);
      }
    });
  }
}

/**
 * Copy content (in use for copy header/footer from template)
 */
function copyContentTo(
  document,
  template,
  isLandscape,
  elementFrom,
  elementTo,
  patterns,
  replaceTexts,
  gradeColors = []
) {
  elementTo.clear();
  var tmplTable = elementFrom.getTables()[0];
  if (!tmplTable)
    return copyParagraphsTo(document, template, elementFrom, elementTo, patterns, replaceTexts);
  var table = elementTo.appendTable(tmplTable.copy());
  for (var i = 0; i < tmplTable.getNumChildren(); i++) {
    appendElementToDoc(table, tmplTable.getChild(i).copy());
  }
  table.removeRow(0);
  for (var i = 0; i < patterns.length; i++) {
    table.replaceText(patterns[i], replaceTexts[i]);
  }

  // adjust for different margins
  var documentWidth =
    document.getPageWidth() - document.getMarginLeft() - document.getMarginRight();
  var templateWidth = template.getPageWidth();
  var templateHeight = template.getPageHeight();
  // need to check this because of mess with width/height templates
  if (
    (isLandscape && templateHeight > templateWidth) ||
    (!isLandscape && templateWidth > templateHeight)
  ) {
    templateWidth = templateHeight - template.getMarginTop() - template.getMarginBottom();
  } else {
    templateWidth = templateWidth - template.getMarginLeft() - template.getMarginRight();
  }
  var ratio = documentWidth / templateWidth;

  table = elementTo.getTables()[0];
  var firstRow = table.getRow(0);
  var numCells = firstRow.getNumChildren();
  for (var iCell = 0; iCell < numCells; iCell++) {
    var cell = firstRow.getChild(iCell).asTableCell();
    cell.setWidth(cell.getWidth() * ratio);
  }

  updateParagraphStyles(elementFrom, elementTo);

  if (gradeColors.length) {
    // Get the first cell in the first row
    var cell = firstRow.getChild(0).asTableCell();
    // Set the background color to yellow
    cell.setBackgroundColor(gradeColors[0]);
    var text = cell.editAsText();
    text.setForegroundColor(gradeColors[1]);
  }
}

/**
 * Copy paragrphs, not tables
 */
function copyParagraphsTo(document, template, elementFrom, elementTo, patterns, replaceTexts) {
  var tmplParagraphs = elementFrom.getParagraphs();
  for (var i = 0; i < tmplParagraphs.length; i++) {
    elementTo.appendParagraph(tmplParagraphs[i].copy());
  }
  for (var i = 0; i < patterns.length; i++) {
    elementTo.replaceText(patterns[i], replaceTexts[i]);
  }

  updateParagraphStyles(elementFrom, elementTo);
}

/**
 * Copy footer from template
 */
function copyFooter(document, template, isLandscape, patterns, replaceTexts) {
  var tmplFooter = template.getFooter();
  if (!tmplFooter || !tmplFooter.getTables()) return;
  var footer = document.getFooter() || document.addFooter();

  // Capture which template paragraph holds each footer placeholder BEFORE
  // substitution. Matching by placeholder (not by scanning non-blank lines)
  // keeps each line's style correct even when a value is empty — otherwise a
  // blank {copyright}/{course} would shift the styles onto the wrong line.
  var lineStyles = footerLineStyles(tmplFooter);

  copyContentTo(document, template, isLandscape, tmplFooter, footer, patterns, replaceTexts);
  styleFooterLines(footer, lineStyles);
}

/**
 * Maps each footer placeholder to its paragraph index within the template
 * footer and the brand style to apply there. copyContentTo copies the template
 * structure and updateParagraphStyles re-aligns doc paragraphs 1:1 with the
 * template, so the same index identifies the line in the generated footer.
 *   {copyright}   -> Lexend, FOOTER_COPYRIGHT_SIZE, normal weight
 *   {course}      -> Lexend, FOOTER_BOLD_SIZE, bold
 *   {unit_lesson} -> Lexend, FOOTER_BOLD_SIZE, bold
 * Placeholders absent from the template (e.g. the material footer's
 * {attribution}) simply contribute nothing.
 */
function footerLineStyles(tmplFooter) {
  var specs = [
    { placeholder: '{copyright}', size: FOOTER_COPYRIGHT_SIZE, bold: false },
    { placeholder: '{course}', size: FOOTER_BOLD_SIZE, bold: true },
    { placeholder: '{unit_lesson}', size: FOOTER_BOLD_SIZE, bold: true }
  ];

  var paragraphs = tmplFooter.getParagraphs();
  var lines = [];
  specs.forEach(function (spec) {
    for (var i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].getText().indexOf(spec.placeholder) !== -1) {
        lines.push({ index: i, size: spec.size, bold: spec.bold });
        break;
      }
    }
  });
  return lines;
}

/**
 * Applies the captured per-line footer styles to the generated footer. Runs
 * AFTER copyContentTo (whose updateParagraphStyles pass resets FONT_SIZE/
 * FONT_FAMILY from the template), so it is the final word on size and weight.
 */
function styleFooterLines(footer, lineStyles) {
  if (!footer || !lineStyles.length) return;

  var paragraphs = footer.getParagraphs();
  lineStyles.forEach(function (line) {
    if (line.index < paragraphs.length) {
      styleParagraphFont(paragraphs[line.index], line.size, line.bold);
    }
  });
}

/**
 * Copy header from template
 */
function copyHeader(document, template, isLandscape, patterns, replaceTexts, gradeColors) {
  var tmplHeader = template.getHeader();
  if (!tmplHeader || !tmplHeader.getTables()) return;
  var header = document.getHeader() || document.addHeader();
  copyContentTo(
    document,
    template,
    isLandscape,
    tmplHeader,
    header,
    patterns,
    replaceTexts,
    gradeColors
  );
  styleHeaderRight(header);
}

/**
 * Applies brand typography to the header's right-side lines. Runs AFTER
 * copyContentTo (whose updateParagraphStyles pass resets FONT_SIZE/FONT_FAMILY
 * from the template), so this is the final word on size and weight:
 *   "Estimated Time: …" -> Lexend, HEADER_ESTIMATED_TIME_SIZE, normal weight
 *   every other line     -> Lexend, HEADER_LESSON_TYPE_SIZE, bold
 * Keyed on the static "Estimated Time" label; the remaining non-empty
 * paragraphs in the same header cell are the title, unit title and lesson type
 * lines, which share one bold treatment. No-op if the label is absent.
 */
function styleHeaderRight(header) {
  if (!header) return;
  var found = header.findText('Estimated Time');
  if (!found) return;

  var estimatedParagraph = found.getElement().getParent().asParagraph();
  styleParagraphFont(estimatedParagraph, HEADER_ESTIMATED_TIME_SIZE, false);

  var cell = parentTableCell(estimatedParagraph);
  if (!cell) return;
  for (var i = 0; i < cell.getNumChildren(); i++) {
    var child = cell.getChild(i);
    if (child.getType() !== DocumentApp.ElementType.PARAGRAPH) continue;

    var paragraph = child.asParagraph();
    var text = paragraph.getText();
    if (text.replace(/\s/g, '') === '' || text.indexOf('Estimated Time') !== -1) continue;

    styleParagraphFont(paragraph, HEADER_LESSON_TYPE_SIZE, true); // title / unit title / lesson type
  }
}

/**
 * Sets Lexend + the given size and weight across a whole paragraph, leaving
 * alignment, colour and spacing untouched.
 */
function styleParagraphFont(paragraph, size, bold) {
  var text = paragraph.editAsText();
  var length = text.getText().length;
  if (length === 0) return;
  text.setFontFamily(0, length - 1, BRAND_FONT);
  text.setFontSize(0, length - 1, size);
  text.setBold(0, length - 1, bold);
}

/**
 * Walks up from an element to its containing TableCell, or null if none.
 */
function parentTableCell(element) {
  var el = element;
  while (el) {
    if (el.getType() === DocumentApp.ElementType.TABLE_CELL) return el.asTableCell();
    el = el.getParent();
  }
  return null;
}

/**
 * Set margins and page width/height from template
 */
function setMargins(document, template, isLandscape = false) {
  var templateWidth = template.getPageWidth();
  var templateHeight = template.getPageHeight();
  if (
    (isLandscape && templateHeight > templateWidth) ||
    (!isLandscape && templateWidth > templateHeight)
  ) {
    document.setPageHeight(templateWidth);
    document.setPageWidth(templateHeight);
  } else {
    document.setPageHeight(templateHeight);
    document.setPageWidth(templateWidth);
  }
  var documentWidth =
    document.getPageWidth() - document.getMarginLeft() - document.getMarginRight();
  var body = document.getBody();
  updateInlinedImages(body, documentWidth);
  // we support left/right alignment and no restriction on image size
  updatePositionedImages(body, documentWidth);
}

/**
 * Returns the Text element with page-break placeholder
 */
function findBreak(body) {
  var el = body.findText('--GDOC-PAGE-BREAK--');
  return el ? el.getElement() : null;
}

/**
 * Inserts page-breaks instead of placeholders
 */
function processPageBreaks(document) {
  var body = document.getBody();

  var breakElement = findBreak(body);
  while (breakElement) {
    var breakParent = breakElement.getParent();
    var index = breakParent.getChildIndex(breakElement);

    try {
      breakParent.insertPageBreak(index);

      const style = {};
      style[DocumentApp.Attribute.LINE_SPACING] = 0.1;
      style[DocumentApp.Attribute.SPACING_AFTER] = 0;
      style[DocumentApp.Attribute.SPACING_BEFORE] = 0;
      style[DocumentApp.Attribute.FONT_SIZE] = 1;

      breakParent.setAttributes(style);
    } catch (err) {
      Logger.log(err);
    } finally {
      breakElement.removeFromParent();
    }

    breakElement = findBreak(body);
  }
}

/**
 * Replaces the {page_number} placeholder in the running footer with a LIVE page
 * number.
 *
 * This cannot go through the footerPatterns/replaceText path Rails drives: a
 * page number is not text but its own PageNumber element, so replaceText could
 * only ever write a fixed string (every page would read the same number). The
 * placeholder is therefore left untouched by the substitution pass and swapped
 * here for a real element.
 *
 * appendPageNumber() appends at the END of the paragraph, which is where a page
 * number belongs (the template puts {page_number} last on its line, after the
 * right-tab). No-op when the placeholder is absent, so a template without one
 * simply gets no page number.
 *
 * Must run AFTER copyFooter, which replaces the footer with a fresh copy of the
 * template footer (where the {page_number} placeholder lives).
 */
function insertFooterPageNumber(document) {
  Logger.log('page number: ' + pageNumberInsert(document));
}

function pageNumberInsert(document) {
  var footer = document.getFooter();
  if (!footer) return 'skipped — document has no footer';
  var found = footer.findText('{page_number}');
  if (!found) return 'skipped — {page_number} not found in footer';

  var textEl = found.getElement().asText();

  try {
    // asParagraph(): getParent() returns a generic ContainerElement, which has
    // no appendPageNumber (same cast as brandmarkInsert / styleHeaderRight).
    // Inside the try: a placeholder whose parent is not a paragraph would
    // otherwise throw uncaught and abort the whole of postProcessing.
    var paragraph = textEl.getParent().asParagraph();
    // Insert the live element BEFORE deleting the placeholder text: if this
    // throws, the footer keeps its {page_number} marker instead of losing both
    // (this catch only reaches Logger).
    var pageNumber = paragraph.appendPageNumber();
    // styleFooterLines already ran (inside copyFooter), so this element is not
    // covered by it — style it directly to match the bold breadcrumb line it
    // shares.
    pageNumber.setFontFamily(BRAND_FONT).setFontSize(FOOTER_BOLD_SIZE).setBold(true);
    textEl.deleteText(found.getStartOffset(), found.getEndOffsetInclusive());
    return 'inserted OK';
  } catch (err) {
    return 'insert failed: ' + err;
  }
}

/**
 * Replaces the {brandmark_url} placeholder in the running header with the client
 * logo. Rails passes the logo inline as a base64 data URI (Settings brandmark),
 * so the image is decoded here — no UrlFetchApp, hence no script.external_request
 * scope and no dependency on the source URL being publicly fetchable by Google.
 * No-op when the data is blank, the placeholder is absent, or decoding fails, so
 * a missing/broken logo never breaks the export — it just leaves the header
 * without an image.
 *
 * Must run AFTER copyHeader, which replaces the header with a fresh copy of the
 * template header (where the {brandmark_url} placeholder lives).
 */
function insertHeaderBrandmark(document, brandmarkData) {
  Logger.log('brandmark: ' + brandmarkInsert(document, brandmarkData));
}

function brandmarkInsert(document, brandmarkData) {
  if (!brandmarkData) return 'skipped — blank data from Rails';
  var header = document.getHeader();
  if (!header) return 'skipped — document has no header';
  var found = header.findText('{brandmark_url}');
  if (!found) return 'skipped — {brandmark_url} not found in header';

  // Expect a base64 data URI: data:<mime>;base64,<payload>
  var match = brandmarkData.match(/^data:([^;]+);base64,(.*)$/);
  if (!match) return 'skipped — brandmark is not a base64 data URI';

  var textEl = found.getElement().asText();

  try {
    // asParagraph(): getParent() returns a generic ContainerElement, which has
    // no appendInlineImage (see styleHeaderRight, which casts the same way).
    // Inside the try: this runs BEFORE insertFooterPageNumber, so an uncaught
    // throw here would abort postProcessing and silently skip the page number.
    var paragraph = textEl.getParent().asParagraph();
    var blob = Utilities.newBlob(Utilities.base64Decode(match[2]), match[1], 'brandmark');
    // Insert the logo BEFORE dropping the placeholder text: if the insert
    // throws, the header keeps its {brandmark_url} marker instead of losing
    // both the logo and the placeholder (this catch only reaches Logger).
    var image = paragraph.appendInlineImage(blob);
    // Delete only the placeholder's own range. setText('') would wipe the whole
    // text run, taking any other placeholder or label authored beside it in the
    // same run (e.g. "{brandmark_url}  {unit_title}") with it.
    textEl.deleteText(found.getStartOffset(), found.getEndOffsetInclusive());
    // Scale down to a header-sized height, preserving aspect ratio.
    var maxHeight = 48;
    if (image.getHeight() > maxHeight) {
      var ratio = maxHeight / image.getHeight();
      image.setWidth(Math.round(image.getWidth() * ratio));
      image.setHeight(maxHeight);
    }
    return 'inserted OK (' + match[1] + ', ' + match[2].length + ' b64 chars)';
  } catch (err) {
    return 'insert failed: ' + err;
  }
}

/**
 * Google Docs' default Heading styles carry a large "space above" (~16-18pt)
 * that HTML import cannot override — it shows up as an empty line above every
 * sub-heading (e.g. "Before teaching Class Session 1" under "Lesson
 * Preparation") and over-spaces the flat activity list. Bring heading spacing
 * down to the brand gap so headings sit tight to their content, matching the
 * PDF. The flat layout relies on this space to separate activities, so it is
 * REDUCED, not zeroed. Tune HEADING_SPACE_BEFORE / _AFTER to taste (points).
 */
var HEADING_SPACE_BEFORE = 6;
var HEADING_SPACE_AFTER = 4;
function tightenHeadings(document) {
  var paragraphs = document.getBody().getParagraphs();
  for (var i = 0; i < paragraphs.length; i++) {
    var paragraph = paragraphs[i];
    if (paragraph.getHeading() !== DocumentApp.ParagraphHeading.NORMAL) {
      paragraph.setSpacingBefore(HEADING_SPACE_BEFORE);
      paragraph.setSpacingAfter(HEADING_SPACE_AFTER);
    }
  }
}

/**
 * Removes the blank paragraph that sits directly after a heading.
 *
 * The exported HTML deliberately puts a near-invisible paragraph at the top of
 * a section body (`.c-gdoc-heading-break`, 1pt, in documents/gdoc/_header.html.erb):
 * Google Docs' import demotes a heading that is the FIRST child of a container
 * to Normal text, so that paragraph keeps the authored sub-heading from being
 * first. Drive honours the trick but NOT the 1pt size — the imported paragraph
 * comes back at full Normal height, leaving a visible gap under headings like
 * "Lesson Preparation".
 *
 * By the time this runs the import is done and the spacer has served its
 * purpose, so it can be dropped. Only whitespace-only paragraphs immediately
 * following a heading are removed, and never the last paragraph of the body
 * (Apps Script requires a document to keep at least one).
 */
function removeBlankParagraphsAfterHeadings(document) {
  var body = document.getBody();
  var paragraphs = body.getParagraphs();

  for (var i = paragraphs.length - 1; i > 0; i--) {
    var paragraph = paragraphs[i];
    if (paragraph.getText().replace(/[\s ]/g, '') !== '') continue;
    // Keep a blank that carries content of its own (an inline image spacer).
    if (paragraph.getNumChildren() > 1) continue;
    if (paragraphs[i - 1].getHeading() === DocumentApp.ParagraphHeading.NORMAL) continue;
    if (body.getNumChildren() <= 1) break;

    paragraph.removeFromParent();
  }
}

/**
 * Main function to call after uploading document
 */
function postProcessing(
  documentId,
  templateId,
  isLandscape = false,
  footerPatterns = [],
  footerReplaceTexts = [],
  headerPatterns = [],
  headerReplaceTexts = [],
  gradeColors = [],
  brandmarkData = ''
) {
  var document = DocumentApp.openById(documentId);
  var template = DocumentApp.openById(templateId);
  processPageBreaks(document);
  removeBlankParagraphsAfterHeadings(document);
  tightenHeadings(document);
  setMargins(document, template, isLandscape);
  if (footerPatterns.length && footerReplaceTexts.length)
    copyFooter(document, template, isLandscape, footerPatterns, footerReplaceTexts);
  if (headerPatterns.length && headerReplaceTexts.length)
    copyHeader(document, template, isLandscape, headerPatterns, headerReplaceTexts, gradeColors);
  insertHeaderBrandmark(document, brandmarkData);
  insertFooterPageNumber(document);
}
