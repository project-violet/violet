// Evaluated in the resolver sandbox by both the web and native backends.
// Keep missing/invalid sizes as null so page indices never shift.
(function () {
  var images = JSON.parse(hitomi_get_image_list());
  var files = typeof galleryinfo !== 'undefined' && Array.isArray(galleryinfo.files)
    ? galleryinfo.files : [];
  images.dimensions = images.result.map(function (_, index) {
    var file = files[index] || {};
    var width = Number(file.width);
    var height = Number(file.height);
    return Number.isFinite(width) && Number.isFinite(height) && width > 0 && height > 0
      ? { width: width, height: height } : null;
  });
  return JSON.stringify(images);
})()
