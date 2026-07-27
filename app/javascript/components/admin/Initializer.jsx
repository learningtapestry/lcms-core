import $ from 'jquery';
import CurriculumEditor from './curriculum/CurriculumEditor';
import ImageUpload from './ImageUpload';
import ImportStatus from './ImportStatus';
import MultiSelectedOperation from './MultiSelectedOperation';
import React from 'react';
import ReactDOM from 'react-dom';

class Initializer {
  static initialize() {
    // Mount internal components
    Initializer.#initializeCurriculumEditor();
    Initializer.#initializeImageUpload();
    Initializer.#InitializeImportStatus();
    Initializer.#initializeMultiSelectedOperation();

    // Initialize simple HTML objects
    Initializer.#initializeResourcesList();
    Initializer.#initializeSelectAll();
    Initializer.#initializeKeyValueLists();
    Initializer.#initializeCalloutLists();
  }

  static #initializeCurriculumEditor() {
    document.querySelectorAll('[id="#lcms-engine-CurriculumEditor"]').forEach(e => {
      const props = JSON.parse(e.dataset.content);
      e.removeAttribute('data-content');
      ReactDOM.render(<CurriculumEditor {...props} />, e);
    });
  }

  static #initializeImageUpload() {
    document.querySelectorAll('[id="#lcms-engine-ImageUpload"]').forEach(e => {
      const props = JSON.parse(e.dataset.content);
      e.removeAttribute('data-content');
      ReactDOM.render(<ImageUpload {...props} />, e);
    });
  }

  static #InitializeImportStatus() {
    document.querySelectorAll('[id="#lcms-engine-ImportStatus"]').forEach(e => {
      const props = JSON.parse(e.dataset.content);
      e.removeAttribute('data-content');
      ReactDOM.render(<ImportStatus {...props} />, e);
    });
  }

  static #initializeMultiSelectedOperation() {
    document.querySelectorAll('[id="#lcms-engine-MultiSelectedOperation"]').forEach(e => {
      const props = JSON.parse(e.dataset.content);
      e.removeAttribute('data-content');
      ReactDOM.render(<MultiSelectedOperation {...props} />, e);
    });
  }

  static #initializeResourcesList() {
    const page = $('.o-adm-list.o-adm-documents');
    if (!page.length) return;

    page.find('.c-reimport-with-materials__toggle input[type=checkbox]').change(() => {
      const value = $(this).prop('checked') ? 1 : 0;
      page.find('.c-reimport-doc-form .c-reimport-with-materials__field').val(value);
    });
  }

  static #initializeSelectAll() {
    const selector = $('.c-multi-selected--select-all');
    if (!selector.length) return;

    selector.find('input').change(ev => {
      const el = $(ev.target);
      const checked = el.prop('checked');
      $('.table input[type=checkbox][name="selected_ids[]"]').prop('checked', checked);
    });
  }

  // Wires the admin/settings/show/_key_value_list.html.erb widget: "Add row"
  // clones the row <template> into the tbody, "Remove" deletes its own row.
  // Vanilla JS (no Stimulus in this app); each .js-key-value-list wrapper is
  // wired independently (via querySelectorAll + a data-attribute guard) so
  // multiple lists on the same page — and repeat Turbo page loads — don't
  // collide or double-bind.
  static #initializeKeyValueLists() {
    document.querySelectorAll('.js-key-value-list').forEach(widget => {
      if (widget.dataset.keyValueListBound) return;
      widget.dataset.keyValueListBound = 'true';

      const rows = widget.querySelector('.js-key-value-list-rows');
      const template = widget.querySelector('.js-key-value-list-template');
      const addButton = widget.querySelector('.js-key-value-list-add');

      addButton.addEventListener('click', () => {
        rows.appendChild(template.content.cloneNode(true));
      });

      rows.addEventListener('click', event => {
        const removeButton = event.target.closest('.js-key-value-list-remove');
        if (!removeButton) return;

        removeButton.closest('.js-key-value-list-row').remove();
      });
    });
  }

  // Wires the admin/settings/show/_callout_list.html.erb widget: same
  // add/remove-row behavior as #initializeKeyValueLists, scoped to
  // .js-callout-list so it doesn't collide with the key-value-list widget.
  static #initializeCalloutLists() {
    document.querySelectorAll('.js-callout-list').forEach(widget => {
      if (widget.dataset.calloutListBound) return;
      widget.dataset.calloutListBound = 'true';

      const rows = widget.querySelector('.js-callout-list-rows');
      const template = widget.querySelector('.js-callout-list-template');
      const addButton = widget.querySelector('.js-callout-list-add');

      addButton.addEventListener('click', () => {
        rows.appendChild(template.content.cloneNode(true));
      });

      rows.addEventListener('click', event => {
        const removeButton = event.target.closest('.js-callout-list-remove');
        if (!removeButton) return;

        removeButton.closest('.js-callout-list-row').remove();
      });
    });
  }

}

export default Initializer;
