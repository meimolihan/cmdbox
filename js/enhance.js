/**
 * Cmdbox 美化增强脚本
 * 实现：键盘快捷键、相关命令推荐、代码语言标签、Toast 提示等功能
 */

/* ⑲ 键盘快捷键：Ctrl+K 或 / 聚焦搜索框 */
(function() {
  var input = document.getElementById('query');
  if (!input) return;

  document.addEventListener('keydown', function(e) {
    // Ctrl+K 或 Cmd+K
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      input.focus();
      input.select();
    }
    // / 键（非输入状态）
    if (e.key === '/' && document.activeElement !== input && !isInputFocused()) {
      e.preventDefault();
      input.focus();
    }
  });

  function isInputFocused() {
    var active = document.activeElement;
    return active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable);
  }
})();

/* ⑩ 相关命令推荐 */
(function() {
  var relatedContainer = document.getElementById('related-commands');
  var relatedList = document.getElementById('related-list');
  if (!relatedContainer || !relatedList) return;

  // 从页面元数据或全局变量获取当前命令信息
  var currentName = '';
  var currentDesc = '';
  
  // 尝试从页面获取命令信息
  var commandTitle = document.querySelector('.command-name');
  if (commandTitle) {
    currentName = commandTitle.textContent.trim();
  }
  var commandDescEl = document.querySelector('.command-desc');
  if (commandDescEl) {
    currentDesc = commandDescEl.textContent.trim();
  }

  // 如果没有 cmdbox_data 数据，退出
  if (typeof cmdbox_data === 'undefined' || !cmdbox_data || !currentName) {
    relatedContainer.style.display = 'none';
    return;
  }

  // 相关命令分类映射
  var relatedMap = {
    'ls': ['dir', 'vdir', 'tree', 'find', 'locate', 'whereis', 'which'],
    'cd': ['pwd', 'pushd', 'popd', 'dirs', 'mkdir', 'rmdir'],
    'cp': ['mv', 'rm', 'ln', 'scp', 'rsync'],
    'mv': ['cp', 'rm', 'ln', 'rename'],
    'rm': ['cp', 'mv', 'rmdir', 'shred', 'unlink'],
    'mkdir': ['rmdir', 'cd', 'ls', 'install'],
    'cat': ['tac', 'more', 'less', 'head', 'tail', 'nl', 'od'],
    'grep': ['egrep', 'fgrep', 'sed', 'awk', 'cut', 'sort', 'uniq'],
    'find': ['locate', 'whereis', 'which', 'grep', 'xargs'],
    'chmod': ['chown', 'chgrp', 'umask', 'ls', 'stat'],
    'chown': ['chmod', 'chgrp', 'ls', 'stat'],
    'tar': ['gzip', 'gunzip', 'zip', 'unzip', 'compress', 'bzip2'],
    'ps': ['top', 'htop', 'kill', 'killall', 'pgrep', 'pstree', 'jobs'],
    'kill': ['killall', 'pkill', 'ps', 'top', 'trap'],
    'top': ['htop', 'ps', 'uptime', 'free', 'vmstat', 'iostat'],
    'df': ['du', 'ls', 'mount', 'umount', 'fdisk', 'blkid'],
    'du': ['df', 'ls', 'find', 'ncdu'],
    'ping': ['traceroute', 'netstat', 'ss', 'ip', 'ifconfig', 'dig', 'nslookup'],
    'ssh': ['scp', 'sftp', 'rsync', 'telnet', 'nc'],
    'wget': ['curl', 'lynx', 'aria2c'],
    'curl': ['wget', 'lynx', 'httpie'],
    'git': ['svn', 'hg', 'cvs'],
    'vim': ['vi', 'nano', 'emacs', 'ed', 'sed'],
    'sed': ['awk', 'grep', 'cut', 'tr', 'sort', 'uniq'],
    'awk': ['sed', 'grep', 'cut', 'sort', 'perl'],
    'sort': ['uniq', 'cut', 'wc', 'head', 'tail'],
    'head': ['tail', 'cat', 'less', 'more', 'tac'],
    'tail': ['head', 'cat', 'less', 'more', 'tac'],
    'wc': ['cat', 'sort', 'uniq', 'head', 'tail'],
    'diff': ['patch', 'cmp', 'sdiff', 'vimdiff'],
    'man': ['info', 'help', 'whatis', 'apropos', 'tldr'],
    'sudo': ['su', 'visudo', 'pkexec', 'doas'],
    'systemctl': ['service', 'journalctl', 'chkconfig', 'init'],
    'journalctl': ['systemctl', 'dmesg', 'logrotate', 'logger'],
    'crontab': ['at', 'batch', 'systemctl', 'anacron'],
    'iptables': ['nft', 'ufw', 'firewalld', 'ip6tables'],
    'docker': ['podman', 'kubectl', 'docker-compose', 'buildah'],
    'kubectl': ['docker', 'helm', 'minikube', 'kubeadm'],
    'nginx': ['apache2', 'httpd', 'caddy', 'systemctl'],
    'mysql': ['mysqldump', 'mysqladmin', 'mariadb', 'psql'],
    'python': ['python3', 'pip', 'virtualenv', 'conda'],
    'pip': ['conda', 'pip3', 'virtualenv', 'poetry'],
    'npm': ['yarn', 'pnpm', 'npx', 'node'],
    'node': ['npm', 'nvm', 'yarn', 'pnpm']
  };

  // 从描述中提取关键词
  function extractKeywords(desc) {
    if (!desc) return [];
    var stopWords = ['的', '用于', '可以', '一个', '这个', '文件', '命令', '显示', '输出', '输入', '设置', '管理'];
    var words = desc.toLowerCase().split(/[\s,，、;；]+/);
    return words.filter(function(w) {
      return w.length >= 2 && stopWords.indexOf(w) === -1;
    }).slice(0, 5);
  }

  // 获取相关命令列表
  function getRelatedCommands(name) {
    var related = relatedMap[name.toLowerCase()] || [];
    
    // 如果没有预定义的相关命令，尝试从前缀匹配找相似的
    if (related.length === 0 && cmdbox_data) {
      // 提取命令前缀（如 nginx、docker、git 等）
      var prefixMatch = name.match(/^([a-zA-Z0-9]+)[_-]/);
      var prefix = prefixMatch ? prefixMatch[1].toLowerCase() : null;
      
      if (prefix) {
        // 查找具有相同前缀的所有命令
        var allPrefixCommands = cmdbox_data.filter(function(cmd) {
          // 匹配 nginx_、nginx-、docker_ 等前缀
          return cmd.n && (
            cmd.n.toLowerCase().startsWith(prefix + '_') || 
            cmd.n.toLowerCase().startsWith(prefix + '-') ||
            cmd.n.toLowerCase() === prefix
          ) && cmd.n !== name;
        });
        
        related = allPrefixCommands.slice(0, 6).map(function(cmd) { return cmd.n; });
      }
      
      // 如果前缀匹配没找到，尝试从描述中找相似的
      if (related.length === 0) {
        var keywords = extractKeywords(currentDesc);
        related = cmdbox_data.filter(function(cmd) {
          if (cmd.n === name) return false;
          return keywords.some(function(kw) {
            return cmd.d && cmd.d.toLowerCase().indexOf(kw) !== -1;
          });
        }).slice(0, 6).map(function(cmd) { return cmd.n; });
      }
    }
    return related.slice(0, 6);
  }

  // 渲染相关命令
  var related = getRelatedCommands(currentName);
  if (related.length === 0) {
    relatedContainer.style.display = 'none';
    return;
  }

  // 查找命令详情并渲染
  var html = '';
  related.forEach(function(name) {
    var cmd = cmdbox_data.find(function(c) { return c.n === name; });
    if (cmd) {
      html += '<a href="c' + cmd.p + '.html" class="related-item">' +
        '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">' +
        '<polyline points="4 17 10 11 4 5"></polyline>' +
        '<line x1="12" y1="19" x2="20" y2="19"></line>' +
        '</svg>' +
        '<span class="related-name">' + escapeHtml(cmd.n) + '</span>' +
        '<span class="related-desc">' + escapeHtml(cmd.d || '') + '</span>' +
        '</a>';
    }
  });

  if (html) {
    relatedList.innerHTML = html;
  } else {
    relatedContainer.style.display = 'none';
  }
})();

/* ⑦ 代码块语言标签 - 位于复制按钮左侧5px */
(function() {
  function addLanguageLabels() {
    var preBlocks = document.querySelectorAll('pre[class*="language-"]');
    preBlocks.forEach(function(pre) {
      if (pre._langLabelAdded) return;
      pre._langLabelAdded = true;

      var match = pre.className.match(/language-(\w+)/);
      if (match) {
        var label = document.createElement('span');
        label.className = 'code-language-label';
        label.textContent = match[1];
        label.style.cssText = 'position:absolute;font-size:11px;color:#6b7280;opacity:0.6;font-family:"SF Mono",Consolas,monospace;text-transform:uppercase;letter-spacing:0.5px;pointer-events:none;z-index:10;';
        pre.style.position = 'relative';
        pre.appendChild(label);
        positionLabel(pre, label);
      }
    });
  }

  function positionLabel(pre, label) {
    var copyBtn = pre.querySelector('.copied');
    if (copyBtn) {
      var preRect = pre.getBoundingClientRect();
      var btnRect = copyBtn.getBoundingClientRect();
      label.style.top = (btnRect.top - preRect.top) + 'px';
      label.style.right = (preRect.right - btnRect.left + 5) + 'px';
    }
  }

  addLanguageLabels();
  // 对动态加载的代码块重新定位
  if (window.MutationObserver) {
    var obs = new MutationObserver(function(muts) {
      muts.forEach(function(m) {
        if (m.addedNodes.length) addLanguageLabels();
      });
    });
    obs.observe(document.body, { childList: true, subtree: true });
  }
})();



/* ⑳ 自动替换代码块中的 ../sh/ ../bat/ 为当前域名 */
(function() {
  var origin = window.location.origin;
  if (!origin || origin === 'null') return;

  function fixScriptUrls(root) {
    root = root || document;
    // 更新 code 元素文本
    var codes = root.querySelectorAll('pre code');
    for (var i = 0; i < codes.length; i++) {
      var code = codes[i];
      if (code._urlFixed) continue;
      var text = code.textContent || code.innerText;
      if (text.indexOf('../sh/') === -1 && text.indexOf('../bat/') === -1) continue;
      code.textContent = text
        .replace(/\.\.\/sh\//g, origin + '/sh/')
        .replace(/\.\.\/bat\//g, origin + '/bat/');
      code._urlFixed = true;
    }
    // 更新复制按钮的 data-code 属性
    var btns = root.querySelectorAll('[data-code]');
    for (var j = 0; j < btns.length; j++) {
      var btn = btns[j];
      if (btn._urlFixed) continue;
      var dataCode = btn.getAttribute('data-code');
      if (dataCode && (dataCode.indexOf('../sh/') !== -1 || dataCode.indexOf('../bat/') !== -1)) {
        btn.setAttribute('data-code',
          dataCode
            .replace(/\.\.\/sh\//g, origin + '/sh/')
            .replace(/\.\.\/bat\//g, origin + '/bat/')
        );
      }
      btn._urlFixed = true;
    }
  }

  fixScriptUrls();

  if (window.MutationObserver) {
    var obs = new MutationObserver(function(muts) {
      for (var m = 0; m < muts.length; m++) {
        if (muts[m].addedNodes.length) {
          fixScriptUrls(muts[m].target);
        }
      }
    });
    obs.observe(document.body, { childList: true, subtree: true });
  }
})();
