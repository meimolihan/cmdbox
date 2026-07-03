/*! @uiw/copy-to-clipboard v1.0.12 | MIT (c) 2021 Kenny Wong | https://github.com/uiwjs/copy-to-clipboard.git */
!function(e,t){"object"==typeof exports&&"undefined"!=typeof module?module.exports=t():"function"==typeof define&&define.amd?define(t):(e="undefined"!=typeof globalThis?globalThis:e||self).copyTextToClipboard=t()}(this,(function(){"use strict";return function(e,t){const o=document.createElement("textarea");o.value=e,o.setAttribute("readonly",""),o.style={position:"absolute",left:"-9999px"},document.body.appendChild(o);const n=document.getSelection().rangeCount>0&&document.getSelection().getRangeAt(0);o.select();let c=!1;try{c=!!document.execCommand("copy")}catch(e){c=!1}document.body.removeChild(o),n&&document.getSelection&&(document.getSelection().removeAllRanges(),document.getSelection().addRange(n)),t&&t(c)}}));

var _copyToastEl = null;
var _copyToastTimer = null;

function copied(target, str) {
  target.classList.add('active');
  copyTextToClipboard(str || target.dataset.code, function(success) {
    if (!_copyToastEl) {
      _copyToastEl = document.createElement('div');
      _copyToastEl.id = 'copy-toast';
      document.body.appendChild(_copyToastEl);
    }
    clearTimeout(_copyToastTimer);
    _copyToastEl.textContent = success ? '已复制到剪贴板' : '复制失败，请手动复制';
    _copyToastEl.className = success ? 'show success' : 'show error';
    _copyToastTimer = setTimeout(function() {
      _copyToastEl.className = '';
    }, 2000);
    setTimeout(function() {
      target.classList.remove('active');
    }, 2000);
  });
}
