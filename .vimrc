"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugins
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Vundle (vim set-up to work without vundle installed)
set nocompatible "required by vundle
" Automatically setup vundle if possible
if executable('git') && empty(glob("~/.vim/bundle/Vundle.vim"))
    silent !git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    let s:setupvundle=1
endif
if !empty(glob("~/.vim/bundle/Vundle.vim"))
    set rtp+=~/.vim/bundle/Vundle.vim/
    filetype off "off required by Vundle
    call vundle#begin()
    Plugin 'VundleVim/Vundle.vim'
    " Plugins
    Plugin 'bling/vim-airline'             " status line
    Plugin 'ctrlpvim/ctrlp.vim'            " ctrl+p to easy open files from current directory
    "Plugin 'davidhalter/jedi-vim'          " Python autocompletion
    Plugin 'editorconfig/editorconfig-vim' " https://editorconfig.org
    Plugin 'ervandew/supertab'             " Tab completion
    Plugin 'nvie/vim-flake8'               " flake8 vim integration
    Plugin 'scrooloose/nerdcommenter'      " Easy commenting
    Plugin 'scrooloose/nerdtree'           " Filesystem browser
    Plugin 'tpope/vim-fugitive'            " Vim git wrapper
    Plugin 'tpope/vim-repeat'              " Use . to repeat in plugin context (needed for vim-surround)
    Plugin 'tpope/vim-surround'            " Surround sections in parens, brackets, quotes, XML tags, and more (example: cs'] changes '' for [])
    " Syntax
    Plugin 'chase/vim-ansible-yaml'        " yaml syntax highlighting
    Plugin 'docker/docker' , {'rtp': '/contrib/syntax/vim/'} " Docker syntax
    Plugin 'junegunn/limelight.vim'
    Plugin 'scrooloose/syntastic'          " Syntax checking
    call vundle#end()
    filetype plugin indent on
    " This automatically installs plugins on first time vundle setup
    " to install plugins manually run $vim +PluginInstall +qa
    if exists('s:setupvundle') && s:setupvundle
        unlet s:setupvundle
        PluginInstall
        quitall " Close the bundle install window.
    endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugin settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " plugin mappings
    nnoremap <F6> :SyntasticToggleMode<LF>
    nnoremap <F5> :NERDTreeToggle<LF>

    " Jedi plugin
    let jedi#goto_assignments_command = "<F3>"
    let g:jedi#goto_definitions_command = "<F4>"
    let g:jedi#auto_initialization = 1      " Auto init jedi
    let g:jedi#popup_on_dot = 1             " Popup on .
    "let g:jedi#popup_select_first = 0       " Don't select first popup
    let g:jedi#rename_command = "<leader>r" " Rename = ,r

    " SuperTab
    let g:SuperTabDefaultCompletionType = "<c-n>"

    " airline plugin
    set laststatus=2
    set ttimeoutlen=50
    set timeoutlen=5000
    set noshowmode
    let g:bufferline_echo = 0
    let g:airline_powerline_fonts = 1
    let g:Powerline_symbols = "fancy"
    if !exists('g:airline_symbols')
      let g:airline_symbols = {}
    endif
    let g:airline_symbols.space = "\ua0"
    " unicode symbols
    let g:airline_left_sep = '»'
    let g:airline_left_sep = '▶'
    let g:airline_right_sep = '«'
    let g:airline_right_sep = '◀'
    let g:airline_symbols.linenr = '¶'
    let g:airline_symbols.paste = 'ρ'
    let g:airline_symbols.paste = 'Þ'
    let g:airline_symbols.paste = '∥'
    let g:airline_symbols.whitespace = 'Ξ'
    " airline symbols
    let g:airline_left_sep = ''
    let g:airline_left_alt_sep = ''
    let g:airline_right_sep = ''
    let g:airline_right_alt_sep = ''
    let g:airline_symbols.branch = ''
    let g:airline_symbols.readonly = ''
    let g:airline_symbols.linenr = ''

    " syntastic python
    let g:syntastic_python_checkers=['flake8', 'python', 'pep8']
    let g:syntastic_mode_map = { 'mode': 'passive',
                               \ 'active_filetypes': [],
                               \ 'passive_filetypes': [] }
    let g:syntastic_warning_symbol="☢" "☢ ⚠☣▲△!
    let g:syntastic_error_symbol="✗"
    let g:syntastic_enable_signs=1
    " E225 missing whitespace around operator
    " E226 missing whitespace around arithmetic operator
    let g:syntastic_python_flake8_args = '--ignore="E225,E226,E501"'
    " syntastic YAML
    let g:syntastic_yaml_checkers = ['yamllint']
    let g:syntastic_yaml_yamllint_args = '-c ~/.config/yamllint/config'
    " show number of buffers
    let g:airline#extensions#tabline#buffer_nr_show = 1
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sets how many lines of history VIM has to remember
set history=10000

" Use an undo file
if has("persistent_undo")
    set undofile
    " Set a directory to store the undo history
    if !isdirectory(expand("~/.vim/undo/"))
        silent !mkdir -p ~/.vim/undo/ >/dev/null 2>&1
    endif
    set undodir=~/.vim/undo/
endif

" Don't try to be compatible with vi
set nocompatible

" Don't backup with ~ files
set nobackup
" Don't use swapfiles .swp
set noswapfile

" :shell will bring up bash shell
set shell=bash

" Set default file encoding
set encoding=utf-8

" Set to auto read when a file is changed from the outside
set autoread

" For regular expressions turn magic on
set magic

" Map leader from \ to ,
let mapleader=','
let maplocalleader='\'

if has('clipboard')
    " Yanks go on clipboard if vim compiled with +clipboard
    set clipboard+=unnamed
    set clipboard+=unnamedplus
    " Hack for ubuntu 16.04 loading slowly without this
    set clipboard=exclude:.*
endif

" Open new split below or vsplit right
"set splitbelow "temporarily off due to jedi or supertab plugin issue
set splitright

" set paste mode to F2
set pastetoggle=<F2>

" Tab completion for insert mode
set completeopt=longest,menuone,preview
" Ctrl+Space to open omni completion menu closing previous if open and opening new menu without changing the text
inoremap <expr> <C-Space> (pumvisible() ? (col('.') > 1 ? '<Esc>i<Right>' : '<Esc>i') : '') .
            \ '<C-x><C-o><C-r>=pumvisible() ? "\<lt>C-n>\<lt>C-p>\<lt>Down>" : ""<CR>'

" Tab completion for command-line mode
set wildmode=longest,list,full
set wildmenu

" Enable mouse support in normal mode
set mouse=n

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Abbreviations
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
iab shebash #!/bin/bash
iab shebashe #!/bin/bash -e
iab shebashx #!/bin/bash -x
iab shebashex #!/bin/bash -ex
iab [bash] #!/usr/bin/env bash
iab shepython #!/usr/bin/python
iab shepy #!/usr/bin/python
iab [python] #!/usr/bin/env python
iab #t <C-V><C-I>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Navigation
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Allows moving beyond eol
set virtualedit=all

" Buffer navigation alt+1 previous alt+2 next
nnoremap <esc>1 :N<CR>
nnoremap <esc>2 :n<CR>

" Prevent escape from moving the cursor one character to the left
"  required for backward/forward ctrl+left/right consistancy
let CursorColumnI = 0 "the cursor column position in INSERT
autocmd InsertEnter * let CursorColumnI = col('.')
autocmd CursorMovedI * let CursorColumnI = col('.')
autocmd InsertLeave * if col('.') != CursorColumnI | call cursor(0, col('.')+1) | endif

" backward/forward ctrl+left/right
nnoremap <C-Left>  b
nnoremap <C-Right> w
inoremap <C-Left>  <esc>bi
inoremap <C-Right> <esc>wi

" Tab navigation like firefox (Doesn't work in most terminals)
nnoremap <C-S-tab> :tabprevious<LF>
nnoremap <C-tab>   :tabnext<LF>
nnoremap <C-t>     :tabnew<LF>
inoremap <C-S-tab> <Esc>:tabprevious<LF>
inoremap <C-tab>   <Esc>:tabnext<LF>
inoremap <C-t>     <Esc>:tabnew<LF>

" Source the vimrc file after saving it
"autocmd BufWritePost .vimrc source $MYVIMRC
" Fast edit the .vimrc file using ',x'
nnoremap <Leader>x :tabedit $MYVIMRC<LF>

" Return to last edit position when opening files
if has("autocmd")
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \ exe "normal! g'\"" |
    \ endif
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set 256 color mode
set t_Co=256
" Popup menu colors
highlight Pmenu ctermfg=2 gui=bold
highlight Pmenu ctermbg=238 gui=bold
" Paren matching colors {}
highlight MatchParen cterm=underline ctermfg=black ctermbg=146
" Enable syntax highlighting
syntax enable
syntax on
highlight Search cterm=NONE ctermfg=black ctermbg=40
" Spelling error highlighting
highlight SpellBad cterm=underline ctermfg=darkred ctermbg=None

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 1 tab == 4 spaces
set tabstop=4
set shiftwidth=4
set softtabstop=4
" Use spaces instead of tabs
set expandtab
" Be smart when using tabs
set smarttab

" Better indentation
set autoindent
set smartindent
set cindent
set cinkeys-=0#
set indentkeys-=0#
" Wrap lines
set wrap
set backspace=indent,eol,start

" yaml indentation
autocmd FileType yaml setlocal tabstop=2 softtabstop=2 shiftwidth=2 expandtab

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Formatting
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set default format options
"    t Auto-wrap text using textwidth
"    c Auto-wrap comments using textwidth, inserting the current comment
"    q Allow formatting of comments with "gq". (Might not need/want this)
"    l Long lines are not broken in insert mode
"    n When formatting text, recognize numbered lists
autocmd FileType * setlocal formatoptions=tcqln
" Formatting turn off automatic comment on o, O and enter
autocmd FileType * setlocal formatoptions-=ro

" Delete trailing whitespace on save
func! FixWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
  set ff=unix
  retab
endfunc
" Auto-fix whitespace on these extensions
"autocmd BufWrite *.py :call FixWS()
"autocmd BufWrite *.xml :call FixWS()
"autocmd BufWrite *.java :call FixWS()
"autocmd BufWrite *.js :call FixWS()
"autocmd BufWrite *.coffee :call FixWS()
"autocmd BufWrite *.yaml :call FixWS()
" ,fs to fix whitespace on other extensions
nnoremap <Leader>fs :call FixWS()<LF>
"autocmd BufWrite *.* :call FixWS()

" toggle line numbers
nnoremap <Leader>n :set number!<LF>

" toggle highlighting
nnoremap <Leader>h :noh<LF>

" xmllint formatting options for xml filetypes
autocmd FileType xml exe "let &l:equalprg='xmllint --format -'"

" Move line up/down with CTRL+up/down arrows
nnoremap <C-Down> :m .+1<CR>==
nnoremap <C-Up> :m .-2<CR>==
inoremap <C-Down> <Esc>:m .+1<CR>==gi
inoremap <C-Up> <Esc>:m .-2<CR>==gi
vnoremap <C-Down> :m '>+1<CR>gv=gv
vnoremap <C-Up> :m '<-2<CR>gv=gv

" Show eol whitespace in red
:autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
:highlight ExtraWhitespace ctermbg=red guibg=red
:match ExtraWhitespace /\s\+$/

" Show tabs and trailing whitespace
set listchars=tab:⇒-,trail:·,    "⇒ ▸ "eol:¬,space:␣
set list

" Ignore case when searching
set ignorecase
" When searching try to be smart about cases
set smartcase
" Highlight search results
set hlsearch
" Highlight search results while typing
"set incsearch

" Always show current position
set ruler

" Show matching brackets when text indicator is over them
set showmatch

" Show line numbers
set number

