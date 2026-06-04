// ==UserScript==
// @name         JenkinsCollapsibleStages
// @namespace    EclipseTech
// @version      1.5
// @description  Collapse/expand pipeline stages in Jenkins console output by stage label
// @match        <jenkins-url>.com/*/console
// @run-at       document-end
// ==/UserScript==

(function () {
    'use strict';

    let allCollapsed = false;

    const btnStyle = {
        padding:      '8px 14px',
        background:   '#1a1a2e',
        color:        '#fff',
        border:       '1px solid #444',
        borderRadius: '6px',
        cursor:       'pointer',
        fontSize:     '13px',
        fontFamily:   'monospace',
        userSelect:   'none',
    };

    function makeBtn(label) {
        const btn = document.createElement('button');
        btn.textContent = label;
        Object.assign(btn.style, btnStyle);
        return btn;
    }

    // --- Shared toolbar ---
    // Structure: #jk-toolbar (fixed, flex row)
    //   ├── #jk-toolbar-arrow  [ > ] / [ < ]
    //   └── #jk-toolbar-btns   (flex row, hidden when collapsed)
    //         └── ... buttons from any script ...
    function getToolbar() {
        let toolbar = document.getElementById('jk-toolbar');
        if (!toolbar) {
            toolbar = document.createElement('div');
            toolbar.id = 'jk-toolbar';
            Object.assign(toolbar.style, {
                position:   'fixed',
                bottom:     '10px',
                right:      '10px',
                zIndex:     '999999',
                display:    'flex',
                gap:        '6px',
                alignItems: 'center',
            });

            const arrowBtn = makeBtn('>');
            arrowBtn.id = 'jk-toolbar-arrow';
            arrowBtn.title = 'Hide toolbar';
            Object.assign(arrowBtn.style, { padding: '8px 10px' });

            const btnGroup = document.createElement('div');
            btnGroup.id = 'jk-toolbar-btns';
            Object.assign(btnGroup.style, {
                display:    'flex',
                gap:        '6px',
                alignItems: 'center',
            });

            arrowBtn.addEventListener('click', () => {
                const hidden = btnGroup.style.display === 'none';
                btnGroup.style.display = hidden ? 'flex' : 'none';
                arrowBtn.textContent = hidden ? '>' : '<';
                arrowBtn.title = hidden ? 'Hide toolbar' : 'Show toolbar';
            });

            toolbar.appendChild(arrowBtn);
            toolbar.appendChild(btnGroup);
            document.body.appendChild(toolbar);
        }
        // Always return the btns group so other scripts append there
        return document.getElementById('jk-toolbar-btns');
    }

    // Collapse/expand all button
    const collapseBtn = makeBtn('⊟');
    collapseBtn.title = 'Collapse all sections';
    getToolbar().prepend(collapseBtn);

    collapseBtn.addEventListener('click', () => {
        allCollapsed = !allCollapsed;
        collapseBtn.textContent = allCollapsed ? '⊞' : '⊟';
        collapseBtn.title = allCollapsed ? 'Expand all sections' : 'Collapse all sections';
        collapseBtn.style.background = allCollapsed ? '#1a2e1a' : '#1a1a2e';

        document.querySelectorAll('.jk-stage-body').forEach(body => {
            body.classList.toggle('collapsed', allCollapsed);
        });
        document.querySelectorAll('.jk-stage-arrow').forEach(arrow => {
            arrow.classList.toggle('collapsed', allCollapsed);
        });
    });

    function init() {
        const out = document.getElementById('out');
        if (!out) return;
        buildCollapsibles(out);
        observeNewContent(out);
    }

    function makeSection(label, nodes, defaultCollapsed) {
        const header = document.createElement('div');
        header.className = 'jk-stage-header';
        header.innerHTML = `<span class="jk-stage-arrow">▼</span> ${label}`;

        const body = document.createElement('div');
        body.className = 'jk-stage-body';
        nodes.forEach(n => body.appendChild(n));

        if (defaultCollapsed) {
            body.classList.add('collapsed');
            header.querySelector('.jk-stage-arrow').classList.add('collapsed');
        }

        header.addEventListener('click', () => {
            const collapsed = body.classList.toggle('collapsed');
            header.querySelector('.jk-stage-arrow').classList.toggle('collapsed', collapsed);
        });

        return { header, body };
    }

    function buildCollapsibles(out) {
        if (out.querySelector('.jk-stage-header')) return;

        const stageNodes = [...out.querySelectorAll('.pipeline-new-node[label]')];
        if (stageNodes.length === 0) return;

        injectStyles();

        // --- Section 1: everything before the first labeled stage node ---
        const firstStage = stageNodes[0];
        const preNodes = [];
        let cursor = out.firstChild;
        while (cursor && cursor !== firstStage) {
            const next = cursor.nextSibling;
            preNodes.push(cursor);
            cursor = next;
        }

        if (preNodes.length > 0) {
            const { header, body } = makeSection('Pipeline', preNodes, true);
            out.insertBefore(header, firstStage);
            out.insertBefore(body, firstStage);
        }

        // --- Sections 2+: each labeled stage ---
        const freshStageNodes = [...out.querySelectorAll('.pipeline-new-node[label]')];

        freshStageNodes.forEach(stageSpan => {
            const label = stageSpan.getAttribute('label');
            const siblings = [];
            let cur = stageSpan.nextSibling;
            while (cur) {
                if (
                    cur.nodeType === Node.ELEMENT_NODE &&
                    cur.classList &&
                    cur.classList.contains('pipeline-new-node') &&
                    cur.hasAttribute('label')
                ) break;
                siblings.push(cur);
                cur = cur.nextSibling;
            }

            if (siblings.length === 0) return;

            const { header, body } = makeSection(`Stage: ${label}`, siblings, false);

            stageSpan.parentNode.insertBefore(header, stageSpan);
            stageSpan.parentNode.insertBefore(body, stageSpan.nextSibling);
            body.insertBefore(stageSpan, body.firstChild);
        });
    }

    function injectStyles() {
        if (document.getElementById('jk-collapse-style')) return;
        const style = document.createElement('style');
        style.id = 'jk-collapse-style';
        style.textContent = `
            .jk-stage-header {
                display: flex;
                align-items: center;
                gap: 6px;
                cursor: pointer;
                user-select: none;
                background: rgba(100,100,200,0.08);
                border-left: 3px solid #6666cc;
                padding: 2px 6px;
                margin: 4px 0 2px;
                font-family: monospace;
                font-size: 13px;
                font-weight: bold;
                color: #aaaaff;
            }
            .jk-stage-header:hover { background: rgba(100,100,200,0.16); }
            .jk-stage-arrow { font-size: 10px; transition: transform 0.15s; display: inline-block; }
            .jk-stage-arrow.collapsed { transform: rotate(-90deg); }
            .jk-stage-body.collapsed { display: none; }
        `;
        document.head.appendChild(style);
    }

    function observeNewContent(out) {
        let debounce;
        const observer = new MutationObserver(() => {
            clearTimeout(debounce);
            debounce = setTimeout(() => buildCollapsibles(out), 500);
        });
        observer.observe(out, { childList: true, subtree: true });
    }

    let attempts = 0;
    const poll = setInterval(() => {
        if (document.getElementById('out') || attempts++ > 20) {
            clearInterval(poll);
            init();
        }
    }, 300);

})();

