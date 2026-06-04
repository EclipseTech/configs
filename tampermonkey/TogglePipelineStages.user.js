// ==UserScript==
// @name         TogglePipelineStages
// @namespace    EclipseTech
// @version      2.4
// @description  Show/hide pipeline-new-node class
// @match        <jenkins-url>.com/*/console
// @run-at       document-end
// ==/UserScript==

(function () {
    'use strict';

    let hidden = false;

    const style = document.createElement('style');
    style.id = 'pipeline-toggle-style';
    document.head.appendChild(style);

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

            const arrowBtn = document.createElement('button');
            arrowBtn.id = 'jk-toolbar-arrow';
            arrowBtn.textContent = '>';
            arrowBtn.title = 'Hide toolbar';
            Object.assign(arrowBtn.style, {
                padding:      '8px 10px',
                background:   '#1a1a2e',
                color:        '#fff',
                border:       '1px solid #444',
                borderRadius: '6px',
                cursor:       'pointer',
                fontSize:     '13px',
                fontFamily:   'monospace',
                userSelect:   'none',
            });

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
        return document.getElementById('jk-toolbar-btns');
    }

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

    const hideBtn = document.createElement('button');
    hideBtn.textContent = 'Hide [Pipeline]';
    Object.assign(hideBtn.style, btnStyle);

    getToolbar().appendChild(hideBtn);

    hideBtn.addEventListener('click', () => {
        hidden = !hidden;
        style.textContent = hidden ? '.pipeline-new-node { display: none !important; }' : '';
        hideBtn.textContent = hidden ? 'Show [Pipeline]' : 'Hide [Pipeline]';
        hideBtn.style.background = hidden ? '#5a1a1a' : '#1a1a2e';
    });

})();

