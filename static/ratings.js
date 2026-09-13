// The 4-point visit scale, in one place so the drawer and the bulk page cannot
// drift apart. Stored as 1-4; see migration 016 for why it is not 1-10.
//
// Beauty is the only axis at risk of everything-is-five-stars, so it gets a
// real floor -- "disappointing" is a thing you genuinely feel after a two-hour
// drive to a trickle, in a way "eh" never is. Photo and solitude are worded
// descriptively rather than evaluatively, so they cannot inflate at all:
// nobody feels stingy picking "crowded".
window.WJ_RATINGS = {
  beauty:   { label: 'Beauty',   options: ['disappointing', 'fine', 'beautiful', 'unforgettable'] },
  photo:    { label: 'Photo',    options: ['nope', 'mediocre', 'nice!', 'stunning'] },
  solitude: { label: 'Solitude', options: ['crowded', 'a few people', 'had it to myself', 'bushwhacked'] },
};

// <select> with a blank first option, so "no opinion" stays the default and
// logging a visit remains a one-field action.
window.wjRatingOptions = function (key, id) {
  const spec = window.WJ_RATINGS[key];
  let html = '<option value="">&mdash;</option>';
  spec.options.forEach((text, i) => {
    html += '<option value="' + (i + 1) + '">' + text + '</option>';
  });
  return '<select id="' + id + '" data-rating="' + key + '">' + html + '</select>';
};

// Labelled form, for the drawer. Where a column header already names the axis,
// use wjRatingOptions instead -- repeating the label inside the cell is what
// pushed the bulk page's fields out of alignment.
window.wjRatingSelect = function (key, id) {
  return '<label class="rate" for="' + id + '">' + window.WJ_RATINGS[key].label +
    window.wjRatingOptions(key, id) + '</label>';
};

window.wjRatingText = function (key, value) {
  if (value === null || value === undefined) return '';
  const spec = window.WJ_RATINGS[key];
  return spec.options[value - 1] || String(value);
};
