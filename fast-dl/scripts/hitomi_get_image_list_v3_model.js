// Ported from hitomi.la common.js (2026-03).
// Placeholders are replaced at runtime with values from gg.js.

function create_download_url(id) {
  return "https://ltn.gold-usergeneratedcontent.net/galleries/" + id + ".js";
}

var domain2 = 'gold-usergeneratedcontent.net';

var gg_m_arr = [%%gg.m%];
var gg_b = "%%gg.b%";
var gg = {
  m: function(g) { return gg_m_arr[g] || 0; },
  s: %%gg.s%,
  b: gg_b
};

function subdomain_from_url(url, base, dir) {
  var retval = '';
  if (!base) {
    if (dir === 'webp') {
      retval = 'w';
    } else if (dir === 'avif') {
      retval = 'a';
    }
  }

  var b = 16;
  var r = /\/[0-9a-f]{61}([0-9a-f]{2})([0-9a-f])/;
  var m = r.exec(url);
  if (!m) {
    return retval;
  }

  var g = parseInt(m[2]+m[1], b);
  if (!isNaN(g)) {
    if (base) {
      retval = String.fromCharCode(97 + gg.m(g)) + base;
    } else {
      retval = retval + (1+gg.m(g));
    }
  }

  return retval;
}

function url_from_url(url, base, dir) {
  return url.replace(/\/\/..?\.gold-usergeneratedcontent\.net\//, '//'+subdomain_from_url(url, base, dir)+'.'+domain2+'/');
}

function full_path_from_hash(hash) {
  return gg.b+gg.s(hash)+'/'+hash;
}

function real_full_path_from_hash(hash) {
  return hash.replace(/^.*(..)(.)$/, '$2/$1/'+hash);
}

function url_from_hash(galleryid, image, dir, ext) {
  ext = ext || dir || image.name.split('.').pop();
  if (dir === 'webp' || dir === 'avif') {
    dir = '';
  } else {
    dir += '/';
  }
  return 'https://a.'+domain2+'/'+dir+full_path_from_hash(image.hash)+'.'+ext;
}

function url_from_url_from_hash(galleryid, image, dir, ext, base) {
  if ('tn' === base) {
    return url_from_url('https://a.'+domain2+'/'+dir+'/'+real_full_path_from_hash(image.hash)+'.'+ext, base);
  }
  return url_from_url(url_from_hash(galleryid, image, dir, ext), base, dir);
}

function hitomi_get_image_list() {
  var files = galleryinfo["files"];
  var result = [];
  var btresult = [];
  var stresult = [];

  for (var i = 0; i < files.length; i++) {
    var file = files[i];

    if (file["hasavif"] == 1) {
      result.push(url_from_url_from_hash(galleryinfo["id"], file, 'avif'));
    } else {
      result.push(url_from_url_from_hash(galleryinfo["id"], file, 'webp'));
    }

    if (file["haswebp"] == 1) {
      btresult.push(url_from_url_from_hash(galleryinfo["id"], file, 'webpbigtn', 'webp', 'tn'));
      stresult.push(url_from_url_from_hash(galleryinfo["id"], file, 'webpsmalltn', 'webp', 'tn'));
    } else if (file["hasavif"] == 1) {
      btresult.push(url_from_url_from_hash(galleryinfo["id"], file, 'avifbigtn', 'avif', 'tn'));
      stresult.push(url_from_url_from_hash(galleryinfo["id"], file, 'avifsmalltn', 'avif', 'tn'));
    } else {
      btresult.push(url_from_url_from_hash(galleryinfo["id"], file, 'bigtn', 'jpg', 'tn'));
      stresult.push(url_from_url_from_hash(galleryinfo["id"], file, 'smalltn', 'jpg', 'tn'));
    }
  }

  return JSON.stringify({
    result: result,
    btresult: btresult,
    stresult: stresult
  });
}

function hitomi_get_header_content(id) {
  return JSON.stringify({
    'referer': 'https://hitomi.la/reader/' + id + '.html',
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
  });
}
