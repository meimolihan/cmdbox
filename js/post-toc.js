// 文章详情页目录（TOC）功能
(function () {
  'use strict';

  function init() {
    var tocLinks = Array.prototype.slice.call(document.querySelectorAll('.post-toc-link'));
    if (tocLinks.length === 0) return;

    var article = document.getElementById('article-content') || document.querySelector('.markdown-body');
    var headings = article
      ? Array.prototype.slice.call(article.querySelectorAll('h1, h2, h3, h4, h5, h6'))
      : [];
    // 目录只收录 h1~h4，滚动高亮与兜底映射都基于同一集合
    var tocHeadings = headings.filter(function (h) { return /^H[1-4]$/.test(h.tagName); });

    /* ---------- 工具 ---------- */
    function normalizeText(s) {
      return (s || '').replace(/\s+/g, '').toLowerCase();
    }
    function headingText(h) {
      var clone = h.cloneNode(true);
      var anchors = clone.querySelectorAll('a.anchor');
      Array.prototype.forEach.call(anchors, function (a) { a.parentNode.removeChild(a); });
      return normalizeText(clone.textContent);
    }
    function findById(id) {
      if (!id) return null;
      var el = document.getElementById(id);
      if (el) return el;
      // 兜底：id 含特殊字符时属性选择器可能更宽容，先转义反斜杠与引号
      try {
        return document.querySelector('[id="' + id.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"]');
      } catch (err) {
        return null;
      }
    }
    var headingIndex = tocHeadings.map(function (h, i) {
      return { el: h, id: h.id, key: headingText(h), index: i };
    });

    /* ---------- 1. 锚点兜底重映射 ---------- */
    // 构建期已把 href 与真实 heading id 对齐；这里只兜底「旧 HTML + 新脚本」的组合
    // （CDN/浏览器缓存里的页面仍是旧 href）。按「规范化文本优先、序号兜底」改写。
    function remapTocLinks() {
      [document.getElementById('post-toc-widget'), document.getElementById('mobile-toc-panel')]
        .forEach(function (root) {
          if (!root) return;
          var used = Object.create(null);
          Array.prototype.slice.call(root.querySelectorAll('.post-toc-link'))
            .forEach(function (link, idx) {
              var href = link.getAttribute('href') || '';
              var id = href.charAt(0) === '#' ? href.slice(1) : '';
              if (id && findById(id)) return;                 // 锚点有效，无需处理
              var key = normalizeText(link.textContent);
              var candidates = headingIndex.filter(function (h) {
                return h.key === key && !used[h.id];
              });
              var target = candidates[0] || headingIndex[idx];
              if (!target || !target.id) return;
              used[target.id] = true;
              link.setAttribute('href', '#' + target.id);
              var item = link.closest('.post-toc-item');
              if (item) item.setAttribute('data-toc-id', target.id);
            });
        });
    }
    remapTocLinks();

    /* ---------- 2. 平滑滚动 ---------- */
    var HEADER_OFFSET = 90;
    function scrollToTarget(href, updateHistory) {
      if (!href || href.charAt(0) !== '#') return false;
      var rawId = href.slice(1);
      var target = findById(rawId);
      if (!target) {
        try { target = findById(decodeURIComponent(rawId)); } catch (err) {}
      }
      if (!target) return false;                             // 交给调用方决定是否放行原生跳转
      var top = target.getBoundingClientRect().top + window.pageYOffset - HEADER_OFFSET;
      window.scrollTo({ top: Math.max(0, top), behavior: 'smooth' });
      // 一次点击只写一条历史记录；首屏 hash 补偿不写
      if (updateHistory !== false) {
        try { history.pushState(null, '', href); } catch (err) {}
      }
      return true;
    }

    /* ---------- 3. 移动端目录开合 ---------- */
    // 旧版 closeMobileToc 定义在 setupMobileToc() 内部，却被外层链接点击回调直接调用，
    // 每次点击都抛 "ReferenceError: closeMobileToc is not defined"。现提升到 init 作用域。
    var closeTimer = null;
    function getMobileEls() {
      return {
        mask: document.getElementById('mobile-toc-mask'),
        panel: document.getElementById('mobile-toc-panel')
      };
    }
    function openMobileToc() {
      if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; }
      var els = getMobileEls();
      if (els.mask) { els.mask.classList.add('show'); els.mask.style.display = 'block'; }
      if (els.panel) { els.panel.classList.add('show'); els.panel.style.display = 'flex'; }
      document.body.style.overflow = 'hidden';
    }
    function closeMobileToc() {
      var els = getMobileEls();
      if (els.mask) els.mask.classList.remove('show');
      if (els.panel) els.panel.classList.remove('show');
      // 必须恢复，否则 body.overflow:hidden 会锁住目录点击后的页面滚动
      document.body.style.overflow = '';
      if (closeTimer) clearTimeout(closeTimer);
      closeTimer = setTimeout(function () {
        if (els.mask && !els.mask.classList.contains('show')) els.mask.style.display = 'none';
        if (els.panel && !els.panel.classList.contains('show')) els.panel.style.display = 'none';
        closeTimer = null;
      }, 300);
    }

    /* ---------- 4. 单一事件委托 ---------- */
    // 旧版对移动端链接绑定了两次（全局 .post-toc-link + setupMobileToc 里的面板内链接），
    // 造成双重滚动与双份 history 记录。现所有入口只走这一个捕获阶段监听器，
    // 动态注入的链接同样能被覆盖。
    document.addEventListener('click', function (e) {
      var t = e.target;
      if (!t || !t.closest) return;
      var link = t.closest('.post-toc-link');
      if (link) {
        // 锚点无效时不阻止默认行为，让浏览器原生 hash 跳转兜底，避免「点了完全没反应」
        if (scrollToTarget(link.getAttribute('href'))) e.preventDefault();
        var panel = document.getElementById('mobile-toc-panel');
        if (panel && panel.classList.contains('show')) {
          // 立即关闭：closeMobileToc 会马上恢复 body.overflow，
          // 否则 overflow:hidden 会在收起动画期间锁住刚触发的平滑滚动。
          closeMobileToc();
        }
        return;
      }
      if (t.closest('#mobile-toc-btn')) {
        e.preventDefault();
        e.stopPropagation();
        openMobileToc();
        return;
      }
      if (t.closest('#mobile-toc-close') || t.closest('#mobile-toc-mask')) {
        closeMobileToc();
      }
    }, true);

    /* ---------- 5. 滚动高亮 ---------- */
    function updateActiveToc() {
      if (headingIndex.length === 0) return;
      var scrollPos = window.pageYOffset || document.documentElement.scrollTop;
      var offset = 120;
      var current = null;
      for (var i = headingIndex.length - 1; i >= 0; i--) {
        // 用文档坐标而非 offsetTop（后者相对 offsetParent，嵌套布局下会偏移）
        var docTop = headingIndex[i].el.getBoundingClientRect().top + scrollPos;
        if (docTop - offset <= scrollPos) { current = headingIndex[i]; break; }
      }
      if (!current) current = headingIndex[0];
      if (!current || !current.id) return;
      var wanted = '#' + current.id;
      var matched = [];
      tocLinks.forEach(function (link) {
        // 直接比对 href，不用 CSS.escape（它在属性选择器引号内会转义错）
        var hit = link.getAttribute('href') === wanted;
        link.classList.toggle('active', hit);
        var item = link.closest('.post-toc-item');
        if (item) item.classList.toggle('active', hit);
        if (hit) matched.push(link);
      });
      matched.forEach(function (link) {
        var box = link.closest('.post-toc-body') || link.closest('.mobile-toc-panel-body');
        if (!box) return;
        var lr = link.getBoundingClientRect();
        var br = box.getBoundingClientRect();
        // 只滚动目录容器，不用 scrollIntoView（会连带滚动整页）
        if (lr.top < br.top) box.scrollTop -= (br.top - lr.top) + 8;
        else if (lr.bottom > br.bottom) box.scrollTop += (lr.bottom - br.bottom) + 8;
      });
    }
    var ticking = false;
    window.addEventListener('scroll', function () {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(function () { updateActiveToc(); ticking = false; });
    }, { passive: true });
    updateActiveToc();

    /* ---------- 6. 桌面端收起/展开 ---------- */
    var tocToggle = document.getElementById('post-toc-toggle');
    var tocWidget = document.getElementById('post-toc-widget');
    if (tocToggle && tocWidget) {
      tocToggle.addEventListener('click', function () {
        var collapsed = tocWidget.classList.toggle('collapsed');
        tocToggle.setAttribute('aria-label', collapsed ? '展开目录' : '收起目录');
        tocToggle.innerHTML = collapsed
          ? '<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>'
          : '<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>';
      });
    }

    /* ---------- 7. 首屏带 hash 访问时补偿固定顶栏 ---------- */
    if (window.location.hash && window.location.hash.length > 1) {
      window.requestAnimationFrame(function () {
        window.requestAnimationFrame(function () {
          scrollToTarget(window.location.hash, false);
        });
      });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
