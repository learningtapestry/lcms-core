// Asks for confirmation before following any link or pressing any button
// that carries data-confirm="Message". Rails UJS is not loaded and Turbo only
// reads data-turbo-confirm (and only on Turbo-driven forms), so without this
// data-confirm did nothing. Listening in the capture phase runs before Turbo's
// own click handling, so a cancelled click never reaches it.
document.addEventListener('click', (event) => {
  const el = event.target.closest('[data-confirm]');
  if (!el || window.confirm(el.dataset.confirm)) return;

  event.preventDefault();
  event.stopImmediatePropagation();
}, true);
