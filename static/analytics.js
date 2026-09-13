// Google Analytics config. The loader itself is a separate async <script> tag
// on each page; this is only the initialisation that would otherwise be copied
// inline four times, drifting the moment the property id changes.
window.dataLayer = window.dataLayer || [];
function gtag() { dataLayer.push(arguments); }
gtag('js', new Date());
gtag('config', 'G-Z01BFBJM7V');
