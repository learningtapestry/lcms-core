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
// Unit title sits one step below the lesson type, matching
// .c-lesson-banner__unit in app/assets/stylesheets/pdf.scss.
var HEADER_UNIT_TITLE_SIZE = 11;
var HEADER_ESTIMATED_TIME_SIZE = 11;
// Footer typography (see footerLineStyles): the copyright line is normal weight; the
// course and unit/lesson lines are bold and one point larger. Sizes are set for
// the Gdoc footer per the styling spec (larger than the PDF footer in
// app/assets/stylesheets/pdf_plain.scss).
var FOOTER_COPYRIGHT_SIZE = 11;
var FOOTER_BOLD_SIZE = 12;
// Bundled-document chrome (Teacher Bundle to Print; template
// GOOGLE_APPLICATION_TEMPLATE_BUNDLE), per the spec's Bundle Header / Footer:
// the header's course name is 12pt bold, right justified; the footer's
// copyright line is 10pt, left justified, and its breadcrumb and page number
// are 10pt bold with 6pt before, the page number right justified. All black.
// Keep in sync with .c-bundle-footer / .c-bundle-header in
// app/assets/stylesheets/pdf_plain.scss.
var BUNDLE_FOOTER_SIZE = 10;
var HEADER_COURSE_SIZE = 12;
var BUNDLE_TEXT_COLOR = '#000000';
var BUNDLE_BREADCRUMB_SPACE_BEFORE = 6;
// Rendered height of the Creative Commons badge in the bundled footer.
var CC_LOGO_MAX_HEIGHT = 15;
// tags
var RE_SIZE = /\[(?:\d+)\]/;

// Bumped by hand whenever this file changes in a way the server needs to see.
// postProcessing returns it and Google::ScriptService logs it, so a wrong-looking
// export can be told apart from an Apps Script deployment that predates the fix
// for it. Apps Script exposes no version of its own over scripts.run: the API
// executes the version pinned to the deployment, NOT the file saved in the
// editor, unless GOOGLE_APPLICATION_SCRIPT_DEV_MODE=true.
var SCRIPT_VERSION = '2026-10-23b';

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
    // check if this is our image, should contain [size] as description:
    // the image's width as a percentage of the page or table cell
    // ([image: id, size] tags; the unit cover uses [100])
    var sizeMatch = altDescription ? altDescription.match(RE_SIZE) : null;
    if (!sizeMatch) continue;
    var percent = Math.min(Math.max(parseInt(sizeMatch[0].replace(/\D/g, ''), 10) || 100, 1), 100);
    var parentWidth = getParentWidth(parent, documentWidth);
    var previousWidth = img.getWidth();
    var previousHeight = img.getHeight();
    var newWidth = (parentWidth / PX_TO_PT) * percent / 100;
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
    { placeholder: '{unit_lesson}', size: FOOTER_BOLD_SIZE, bold: true },
    {
      placeholder: '{bundle_copyright}', size: BUNDLE_FOOTER_SIZE, bold: false,
      color: BUNDLE_TEXT_COLOR, align: DocumentApp.HorizontalAlignment.LEFT
    },
    {
      placeholder: '{bundle_breadcrumb}', size: BUNDLE_FOOTER_SIZE, bold: true,
      color: BUNDLE_TEXT_COLOR, align: DocumentApp.HorizontalAlignment.LEFT,
      spaceBefore: BUNDLE_BREADCRUMB_SPACE_BEFORE, pageNumberBeside: true
    }
  ];

  var paragraphs = tmplFooter.getParagraphs();
  var lines = [];
  specs.forEach(function (spec) {
    for (var i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].getText().indexOf(spec.placeholder) !== -1) {
        var line = { index: i };
        for (var key in spec) if (key !== 'placeholder') line[key] = spec[key];
        lines.push(line);
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
    if (line.index >= paragraphs.length) return;

    var paragraph = paragraphs[line.index];
    styleChromeLine(paragraph, line);
    if (line.pageNumberBeside) stylePageNumberBeside(paragraph, line);
  });
}

/**
 * Font, size and weight (styleParagraphFont), plus the colour, alignment and
 * space before a line spec names. The paragraph-level attributes also reach a
 * page number field, which is not text and so escapes styleParagraphFont.
 */
function styleChromeLine(paragraph, line) {
  styleParagraphFont(paragraph, line.size, line.bold);
  var attrs = {};
  attrs[DocumentApp.Attribute.FONT_FAMILY] = BRAND_FONT;
  attrs[DocumentApp.Attribute.FONT_SIZE] = line.size;
  attrs[DocumentApp.Attribute.BOLD] = line.bold;
  if (line.color) attrs[DocumentApp.Attribute.FOREGROUND_COLOR] = line.color;
  paragraph.setAttributes(attrs);
  if (line.align) paragraph.setAlignment(line.align);
  if (line.spaceBefore !== undefined) paragraph.setSpacingBefore(line.spaceBefore);
}

/**
 * The page number sits in the table cell(s) beside the breadcrumb, on the same
 * row: same type and spacing as the breadcrumb, right justified. When the
 * template puts it in the breadcrumb's own paragraph (after a tab) instead,
 * styleChromeLine has already styled it.
 */
function stylePageNumberBeside(paragraph, line) {
  var cell = parentTableCell(paragraph);
  if (!cell) return;

  var row = cell.getParentRow();
  var own = row.getChildIndex(cell);
  for (var c = 0; c < row.getNumCells(); c++) {
    if (c === own) continue;
    var other = row.getCell(c);
    for (var i = 0; i < other.getNumChildren(); i++) {
      if (other.getChild(i).getType() !== DocumentApp.ElementType.PARAGRAPH) continue;
      styleChromeLine(other.getChild(i).asParagraph(), {
        size: line.size, bold: line.bold, color: line.color,
        align: DocumentApp.HorizontalAlignment.RIGHT, spaceBefore: line.spaceBefore
      });
    }
  }
}

/**
 * Copy header from template
 */
function copyHeader(document, template, isLandscape, patterns, replaceTexts, gradeColors) {
  var tmplHeader = template.getHeader();
  if (!tmplHeader || !tmplHeader.getTables()) return;
  var header = document.getHeader() || document.addHeader();
  // Capture which paragraph holds {unit_title} BEFORE substitution replaces it
  // with a value there is no longer anything to match on. The footer does the
  // same (see footerLineStyles).
  var unitTitleIndex = headerParagraphIndex(tmplHeader, '{unit_title}');
  var courseIndex = headerParagraphIndex(tmplHeader, '{course}');
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
  styleHeaderUnitTitle(header, unitTitleIndex);
  if (courseIndex >= 0 && courseIndex < header.getParagraphs().length) {
    styleChromeLine(header.getParagraphs()[courseIndex], {
      size: HEADER_COURSE_SIZE, bold: true, color: BUNDLE_TEXT_COLOR,
      align: DocumentApp.HorizontalAlignment.RIGHT
    });
  }
}

/**
 * Index of the template-header paragraph containing `placeholder`, or -1 when
 * the template does not define it. copyContentTo's updateParagraphStyles pass
 * re-aligns the generated header's paragraphs 1:1 with the template's, so the
 * same index identifies the line in the generated header.
 */
function headerParagraphIndex(tmplHeader, placeholder) {
  var paragraphs = tmplHeader.getParagraphs();
  for (var i = 0; i < paragraphs.length; i++) {
    if (paragraphs[i].getText().indexOf(placeholder) !== -1) return i;
  }
  return -1;
}

/**
 * Drops the unit-title line to HEADER_UNIT_TITLE_SIZE. Must run AFTER
 * styleHeaderRight, which paints every header line except "Estimated Time" at
 * HEADER_LESSON_TYPE_SIZE — this is the exception to that. No-op when the
 * template has no {unit_title} placeholder.
 */
function styleHeaderUnitTitle(header, index) {
  if (!header || index < 0) return;

  var paragraphs = header.getParagraphs();
  if (index >= paragraphs.length) return;

  styleParagraphFont(paragraphs[index], HEADER_UNIT_TITLE_SIZE, true);
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
 * Deletes a leftover {page_number} marker from the running footer.
 *
 * Page numbers are NOT produced here. Apps Script has no appendPageNumber and
 * the Docs REST API can read an AutoText page number but cannot insert one, so
 * an earlier design that swapped this marker for a live element was
 * unimplementable and failed on every export. The page number is now a native
 * field in the Drive template's footer (Insert -> Page numbers), which
 * copyFooter copies across without any help from this file.
 *
 * This remains only as a guard: a template that still carries the old marker
 * would otherwise print the literal text "{page_number}" at the bottom of every
 * exported lesson. Once no template contains it, this can go.
 *
 * Must run AFTER copyFooter, which replaces the footer with a fresh copy of the
 * template footer.
 */
function stripFooterPageNumberPlaceholder(document) {
  var footer = document.getFooter();
  if (!footer) return 'skipped — document has no footer';
  var found = footer.findText('{page_number}');
  if (!found) return 'clean — no marker in footer';

  try {
    // Delete only the marker's own range. setText('') would wipe the whole text
    // run, taking any label authored beside it with it (see brandmarkInsert).
    found.getElement().asText().deleteText(found.getStartOffset(), found.getEndOffsetInclusive());
    return 'stale {page_number} marker stripped — remove it from the template';
  } catch (err) {
    return 'strip failed: ' + err;
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
  var status = brandmarkInsert(document, brandmarkData);
  Logger.log('brandmark: ' + status);
  return status;
}

function brandmarkInsert(document, brandmarkData) {
  return insertImageAtPlaceholder(document.getHeader(), 'header', '{brandmark_url}', brandmarkData, {
    maxHeight: 48,
    before: false
  });
}

/**
 * Replaces the {cc_logo} placeholder in the running footer with the client's
 * Creative Commons badge (Settings cc_logo), inline and BEFORE the copyright
 * text authored beside it ("{cc_logo} {bundle_copyright}"). Same contract as
 * insertHeaderBrandmark; must run AFTER copyFooter.
 */
function insertFooterCcLogo(document, ccLogoData) {
  var status = insertImageAtPlaceholder(document.getFooter(), 'footer', '{cc_logo}', ccLogoData, {
    maxHeight: CC_LOGO_MAX_HEIGHT,
    before: true
  });
  Logger.log('ccLogo: ' + status);
  return status;
}

/**
 * Decodes a base64 data URI from Rails and inserts it as an inline image where
 * `placeholder` sits in `container` (a header or footer), then deletes the
 * placeholder. `before: true` inserts the image in front of the placeholder's
 * text run (for a badge leading a line of text); otherwise it is appended to
 * the paragraph (for a logo alone in its cell). Returns a status string; never
 * throws, so a broken image cannot abort postProcessing.
 */
function insertImageAtPlaceholder(container, containerName, placeholder, data, opts) {
  if (!container) return 'skipped — document has no ' + containerName;
  if (!data) return removePlaceholder(container, placeholder);
  var found = container.findText(placeholder);
  if (!found) return 'skipped — ' + placeholder + ' not found in ' + containerName;

  // Expect a base64 data URI: data:<mime>;base64,<payload>
  var match = data.match(/^data:([^;]+);base64,(.*)$/);
  if (!match) return 'skipped — image is not a base64 data URI';

  var textEl = found.getElement().asText();

  try {
    // asParagraph(): getParent() returns a generic ContainerElement, which has
    // no appendInlineImage (see styleHeaderRight, which casts the same way).
    // Inside the try: postProcessing's remaining steps run after this one, so an
    // uncaught throw here would abort them along with it.
    var paragraph = textEl.getParent().asParagraph();
    var blob = Utilities.newBlob(Utilities.base64Decode(match[2]), match[1], placeholder);
    // Insert the image BEFORE dropping the placeholder text: if the insert
    // throws, the container keeps its marker instead of losing both the image
    // and the placeholder (this catch only reaches Logger).
    var image = opts.before
      ? paragraph.insertInlineImage(paragraph.getChildIndex(textEl), blob)
      : paragraph.appendInlineImage(blob);
    // Delete only the placeholder's own range. setText('') would wipe the whole
    // text run, taking any other placeholder or label authored beside it in the
    // same run (e.g. "{brandmark_url}  {unit_title}") with it.
    textEl.deleteText(found.getStartOffset(), found.getEndOffsetInclusive());
    // Scale down to the target height, preserving aspect ratio.
    if (image.getHeight() > opts.maxHeight) {
      var ratio = opts.maxHeight / image.getHeight();
      image.setWidth(Math.round(image.getWidth() * ratio));
      image.setHeight(opts.maxHeight);
    }
    return 'inserted OK (' + match[1] + ', ' + match[2].length + ' b64 chars)';
  } catch (err) {
    return 'insert failed: ' + err;
  }
}

/**
 * Deletes a placeholder whose image is not configured (no Creative Commons
 * badge when the content is not so licensed, no logo), with the one space
 * authored after it ("{cc_logo} {bundle_copyright}"), so it does not print.
 */
function removePlaceholder(container, placeholder) {
  var pattern = placeholder.replace(/[{}]/g, '\\$&') + ' ?';
  var found = container.findText(pattern);
  if (!found) return 'skipped — blank data from Rails';
  try {
    found.getElement().asText().deleteText(found.getStartOffset(), found.getEndOffsetInclusive());
    return 'blank data from Rails — placeholder removed';
  } catch (err) {
    return 'blank data from Rails — placeholder removal failed: ' + err;
  }
}

/**
 * Turns on Google Docs' "different first page" so page 1 shows the (empty)
 * first-page header/footer instead of the running ones — the unit cover draws
 * its own logo and rule in the body and has no footer.
 *
 * DocumentApp cannot set this, so it goes through the Docs advanced service,
 * which must be enabled for the script (Services > Google Docs API; manifest
 * dependency "Docs" v1). The DocumentApp handle is saved and closed first so
 * the batchUpdate sees every edit made above. Never throws.
 */
function useDistinctFirstPage(document) {
  try {
    var documentId = document.getId();
    document.saveAndClose();
    Docs.Documents.batchUpdate(
      {
        requests: [
          {
            updateDocumentStyle: {
              documentStyle: { useFirstPageHeaderFooter: true },
              fields: 'useFirstPageHeaderFooter'
            }
          }
        ]
      },
      documentId
    );
    return 'set';
  } catch (err) {
    return 'failed: ' + err;
  }
}

/**
 * Styles every heading by level, per the spec's "Styling Details > Headings":
 * Lexend, bold, left justified, with the size, color and space after below
 * (H6 is also italic).
 *
 * Applied here rather than from gdoc.scss because the HTML import keeps a
 * heading only when its <h1>-<h6> tag carries no styling: the templates style
 * an inner <span class="o-gdoc-h*"> instead, but headings authored in the
 * lesson or material content have no such span and would otherwise take the
 * template document's named Heading styles. This covers both, at all six
 * levels.
 *
 * Space before is not in the spec. Google Docs' default Heading styles carry a
 * large one (~16-18pt) that the import cannot override; it is brought down to
 * HEADING_SPACE_BEFORE, not zeroed, because the flat activity layout relies on
 * it to separate activities.
 */
var HEADING_SPACE_BEFORE = 6;
var HEADING_STYLES = [
  { heading: DocumentApp.ParagraphHeading.HEADING1, size: 22, color: '#000000', after: 6 },
  { heading: DocumentApp.ParagraphHeading.HEADING2, size: 18, color: '#000000', after: 6 },
  { heading: DocumentApp.ParagraphHeading.HEADING3, size: 14, color: '#434343', after: 4 },
  { heading: DocumentApp.ParagraphHeading.HEADING4, size: 13, color: '#000000', after: 0 },
  { heading: DocumentApp.ParagraphHeading.HEADING5, size: 12, color: '#434343', after: 0 },
  { heading: DocumentApp.ParagraphHeading.HEADING6, size: 11, color: '#000000', after: 0, italic: true }
];

function headingStyle(paragraph) {
  var heading = paragraph.getHeading();
  for (var i = 0; i < HEADING_STYLES.length; i++) {
    if (HEADING_STYLES[i].heading === heading) return HEADING_STYLES[i];
  }
  return null;
}

function styleHeadings(document) {
  var paragraphs = document.getBody().getParagraphs();
  for (var i = 0; i < paragraphs.length; i++) {
    var paragraph = paragraphs[i];
    var style = headingStyle(paragraph);
    if (!style) continue;

    paragraph.setAlignment(DocumentApp.HorizontalAlignment.LEFT);
    paragraph.setSpacingBefore(HEADING_SPACE_BEFORE);
    paragraph.setSpacingAfter(style.after);

    var text = paragraph.editAsText();
    if (text.getText().length === 0) continue;
    text.setFontFamily(BRAND_FONT);
    text.setFontSize(style.size);
    text.setBold(true);
    text.setForegroundColor(style.color);
    // Only H6 is italic by spec; elsewhere authored italics are kept.
    if (style.italic) text.setItalic(true);
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
  brandmarkData = '',
  ccLogoData = '',
  distinctFirstPage = false
) {
  var document = DocumentApp.openById(documentId);
  var template = DocumentApp.openById(templateId);
  processPageBreaks(document);
  removeBlankParagraphsAfterHeadings(document);
  styleHeadings(document);
  setMargins(document, template, isLandscape);
  if (footerPatterns.length && footerReplaceTexts.length)
    copyFooter(document, template, isLandscape, footerPatterns, footerReplaceTexts);
  if (headerPatterns.length && headerReplaceTexts.length)
    copyHeader(document, template, isLandscape, headerPatterns, headerReplaceTexts, gradeColors);
  var brandmark = insertHeaderBrandmark(document, brandmarkData);
  var ccLogo = insertFooterCcLogo(document, ccLogoData);
  var pageNumber = stripFooterPageNumberPlaceholder(document);
  // Last: it saves and closes the DocumentApp handle.
  var firstPage = distinctFirstPage ? useDistinctFirstPage(document) : 'not requested';

  // Returned to Rails (Google::ScriptService logs it). Everything above fails
  // softly so one broken insert cannot abort the export, which also means a
  // failure is invisible from the server — this is the only channel that
  // carries it back. `version` dates the DEPLOYED script, not the file in the
  // repo: scripts.run executes the version pinned to the API Executable
  // deployment unless GOOGLE_APPLICATION_SCRIPT_DEV_MODE=true, so a stale
  // deployment shows up here as an older date (or as a missing key entirely,
  // from a deployment that predates this return value).
  return {
    version: SCRIPT_VERSION,
    brandmark: brandmark,
    pageNumber: pageNumber,
    ccLogo: ccLogo,
    firstPage: firstPage
  };
}
