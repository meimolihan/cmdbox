// 文章详情页目录（TOC）功能
(function() {
  'use strict';

  function init() {
    var tocList = document.querySelectorAll('.post-toc-list .post-toc-link');
    if (tocList.length === 0) return;

    var article = document.getElementById('article-content') || document.querySelector('.markdown-body');
    var headings = [];
    if (article) {
      headings = Array.prototype.slice.call(article.querySelectorAll('h1, h2, h3, h4, h5, h6'));
    }

    // 为标题添加锚点
    var tocItems = document.querySelectorAll('.post-toc-item');
    tocItems.forEach(function(item) {
      var id = item.getAttribute('data-toc-id');
      var link = item.querySelector('.post-toc-link');
      if (!link) return;
      var text = link.textContent;
      // 尝试找到对应标题
      for (var i = 0; i < headings.length; i++) {
        var h = headings[i];
        var hText = h.textContent.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/`([^`]+)`/g, '$1').trim();
        if (hText === text || hText.indexOf(text) !== -1 || text.indexOf(hText) !== -1) {
          if (!h.id) {
            h.id = id;
          }
          // 如果id不同，尝试用原标题id
          break;
        }
      }
      // 如果还是没找到，直接用toc的id
      if (!item._matchedHeading) {
        for (var j = 0; j < headings.length; j++) {
          if (headings[j].textContent.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/`([^`]+)`/g, '$1').trim() === text) {
            if (!headings[j].id) headings[j].id = id;
            item._matchedHeading = headings[j];
            break;
          }
        }
      }
    });

    // 平滑滚动
    document.querySelectorAll('.post-toc-link').forEach(function(link) {
      link.addEventListener('click', function(e) {
        e.preventDefault();
        var href = this.getAttribute('href');
        if (!href || href.charAt(0) !== '#') return;
        var targetId = href.substring(1);
        var target = document.getElementById(targetId) || document.querySelector('[id="' + targetId.replace(/"/g, '\\"') + '"]');
        if (target) {
          var headerOffset = 90;
          var elementPosition = target.getBoundingClientRect().top;
          var offsetPosition = elementPosition + window.pageYOffset - headerOffset;
          window.scrollTo({
            top: offsetPosition,
            behavior: 'smooth'
          });
          // 更新URL
          try {
            history.pushState(null, '', href);
          } catch (err) {}
        }
        // 移动端关闭
        closeMobileToc();
      });
    });

    // 滚动高亮
    var activeLink = null;
    function updateActiveToc() {
      if (headings.length === 0) return;
      var scrollPos = window.pageYOffset || document.documentElement.scrollTop;
      var offset = 120;
      var current = null;
      for (var i = headings.length - 1; i >= 0; i--) {
        var h = headings[i];
        if (h.offsetTop - offset <= scrollPos) {
          current = h;
          break;
        }
      }
      if (!current && headings.length > 0) current = headings[0];
      if (current) {
        var currentId = current.id;
        document.querySelectorAll('.post-toc-link').forEach(function(link) {
          link.classList.remove('active');
        });
        document.querySelectorAll('.post-toc-item').forEach(function(item) {
          item.classList.remove('active');
        });
        var links = document.querySelectorAll('.post-toc-link[href="#' + CSS.escape(currentId) + '"]');
        links.forEach(function(link) {
          link.classList.add('active');
          var item = link.closest('.post-toc-item');
          if (item) item.classList.add('active');
          // 滚动到可视区域
          var tocNav = document.querySelector('.post-toc-body');
          if (tocNav) {
            var linkTop = link.getBoundingClientRect().top;
            var navTop = tocNav.getBoundingClientRect().top;
            var relativeTop = linkTop - navTop;
            if (relativeTop < 0 || relativeTop > tocNav.clientHeight - 40) {
              link.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
            }
          }
        });
      }
    }

    var ticking = false;
    window.addEventListener('scroll', function() {
      if (!ticking) {
        window.requestAnimationFrame(function() {
          updateActiveToc();
          ticking = false;
        });
        ticking = true;
      }
    }, { passive: true });
    updateActiveToc();

    // 桌面端收起/展开
    var tocToggle = document.getElementById('post-toc-toggle');
    var tocWidget = document.getElementById('post-toc-widget');
    if (tocToggle && tocWidget) {
      tocToggle.addEventListener('click', function() {
        tocWidget.classList.toggle('collapsed');
        if (tocWidget.classList.contains('collapsed')) {
          tocToggle.setAttribute('aria-label', '展开目录');
          tocToggle.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>';
        } else {
          tocToggle.setAttribute('aria-label', '收起目录');
          tocToggle.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>';
        }
      });
    }

    // 移动端
    function setupMobileToc() {
      var mobileBtn = document.getElementById('mobile-toc-btn');
      var mobileMask = document.getElementById('mobile-toc-mask');
      var mobilePanel = document.getElementById('mobile-toc-panel');
      var mobileClose = document.getElementById('mobile-toc-close');

      function openMobileToc() {
        if (mobileMask) {
          mobileMask.classList.add('show');
          mobileMask.style.display = 'block';
        }
        if (mobilePanel) {
          mobilePanel.classList.add('show');
          mobilePanel.style.display = 'flex';
        }
        document.body.style.overflow = 'hidden';
      }
      function closeMobileToc() {
        if (mobileMask) {
          mobileMask.classList.remove('show');
          setTimeout(function() { if (!mobileMask.classList.contains('show')) mobileMask.style.display = 'none'; }, 300);
        }
        if (mobilePanel) {
          mobilePanel.classList.remove('show');
          setTimeout(function() { if (!mobilePanel.classList.contains('show')) mobilePanel.style.display = 'none'; }, 300);
        }
        document.body.style.overflow = '';
      }

      if (mobileBtn) {
        if (mobileBtn._tocBound) return;
        mobileBtn.addEventListener('click', function(e) {
          e.preventDefault();
          e.stopPropagation();
          openMobileToc();
        });
        mobileBtn._tocBound = true;
      }
      if (mobileMask && !mobileMask._tocBound) {
        mobileMask.addEventListener('click', closeMobileToc);
        mobileMask._tocBound = true;
      }
      if (mobileClose && !mobileClose._tocBound) {
        mobileClose.addEventListener('click', closeMobileToc);
        mobileClose._tocBound = true;
      }

      // 移动端目录链接点击关闭
      document.querySelectorAll('#mobile-toc-panel .post-toc-link').forEach(function(link) {
        if (link._tocBound) return;
        link.addEventListener('click', function() {
          setTimeout(closeMobileToc, 300);
        });
        link._tocBound = true;
      });
    }

    setupMobileToc();
    // 防止动态注入导致事件失效，使用委托
    document.addEventListener('click', function(e) {
      var btn = e.target.closest('#mobile-toc-btn');
      if (btn) {
        e.preventDefault();
        e.stopPropagation();
        var mobileMask = document.getElementById('mobile-toc-mask');
        var mobilePanel = document.getElementById('mobile-toc-panel');
        if (mobileMask) {
          mobileMask.classList.add('show');
          mobileMask.style.display = 'block';
        }
        if (mobilePanel) {
          mobilePanel.classList.add('show');
          mobilePanel.style.display = 'flex';
        }
        document.body.style.overflow = 'hidden';
        return;
      }
      var closeBtn = e.target.closest('#mobile-toc-close');
      if (closeBtn) {
        var mobileMask2 = document.getElementById('mobile-toc-mask');
        var mobilePanel2 = document.getElementById('mobile-toc-panel');
        if (mobileMask2) {
          mobileMask2.classList.remove('show');
          setTimeout(function() { if (!mobileMask2.classList.contains('show')) mobileMask2.style.display = 'none'; }, 300);
        }
        if (mobilePanel2) {
          mobilePanel2.classList.remove('show');
          setTimeout(function() { if (!mobilePanel2.classList.contains('show')) mobilePanel2.style.display = 'none'; }, 300);
        }
        document.body.style.overflow = '';
        return;
      }
      var mask = e.target.closest('#mobile-toc-mask');
      if (mask) {
        var mobileMask3 = document.getElementById('mobile-toc-mask');
        var mobilePanel3 = document.getElementById('mobile-toc-panel');
        if (mobileMask3) {
          mobileMask3.classList.remove('show');
          setTimeout(function() { if (!mobileMask3.classList.contains('show')) mobileMask3.style.display = 'none'; }, 300);
        }
        if (mobilePanel3) {
          mobilePanel3.classList.remove('show');
          setTimeout(function() { if (!mobilePanel3.classList.contains('show')) mobilePanel3.style.display = 'none'; }, 300);
        }
        document.body.style.overflow = '';
        return;
      }
    }, true);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
