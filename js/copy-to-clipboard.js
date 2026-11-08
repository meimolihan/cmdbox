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

/* ---------- 通用轻提示：与代码块复制共用 #copy-toast ---------- */
// 详情页「复制链接」的 onclick 一直调用 showToast(...)，但全站从未定义过它，
// 导致复制可能成功却没有任何反馈，并抛出 ReferenceError。
// 这里复用站内已有的 #copy-toast 样式（顶部滑入 / success 绿 / error 红 / 2s 收起），
// 与代码块复制提示保持视觉一致，不新增任何 CSS。
function showToast(message, type) {
  var el = window._copyToastEl;
  if (!el || !el.isConnected) {
    el = document.getElementById('copy-toast') || document.createElement('div');
    el.id = 'copy-toast';
    // 让屏幕阅读器播报复制结果
    el.setAttribute('role', 'status');
    el.setAttribute('aria-live', 'polite');
    if (!el.parentNode) document.body.appendChild(el);
    window._copyToastEl = el;
  }
  clearTimeout(window._copyToastTimer);
  // 先清 class 并强制回流，保证连续点击时滑入动画会重新播放
  el.className = '';
  void el.offsetWidth;
  el.textContent = message || '操作成功';
  el.className = 'show ' + (type === 'error' ? 'error' : 'success');
  window._copyToastTimer = setTimeout(function() {
    el.className = '';
  }, 2000);
}

/* ---------- 详情页「复制链接」 ---------- */
// 旧实现只在 onclick 里同步调用 writeText 后立刻提示成功，
// 既没等 Promise 结果，也没处理「非安全上下文 / 权限被拒 / 文档未聚焦」的失败。
function copyPageLink() {
  var text = window.location.href;
  function fallback() {
    var ok = false;
    try {
      // execCommand 兜底：兼容 http 非 localhost、clipboard 权限被拒等场景
      copyTextToClipboard(text, function(success) { ok = success; });
    } catch (err) {
      ok = false;
    }
    showToast(ok ? '链接已复制成功' : '复制失败，请手动复制', ok ? 'success' : 'error');
  }
  if (navigator.clipboard && navigator.clipboard.writeText) {
    try {
      navigator.clipboard.writeText(text).then(function() {
        showToast('链接已复制成功', 'success');
      }).catch(fallback);
    } catch (err) {
      fallback();
    }
  } else {
    fallback();
  }
}
