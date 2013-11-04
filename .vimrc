"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sets how many lines of history VIM has to remember
set history=10000

set nocompatible " don't try to be compatible with vi

set nobackup

set virtualedit=all

set shell=bash

set encoding=utf-8

" Set to auto read when a file is changed from the outside
set autoread

" Always show current position
set ruler

" Ignore case when searching
" When searching try to be smart about cases
" Highlight search results
set ignorecase
set smartcase
set hlsearch
" set incsearch

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch

" map leader from \ to ,
let mapleader=','
let maplocalleader='\'

" tab navigation like firefox
nnoremap <C-S-tab> :tabprevious<LF>
nnoremap <C-tab>   :tabnext<LF>
nnoremap <C-t>     :tabnew<LF>
inoremap <C-S-tab> <Esc>:tabprevious<LF>
inoremap <C-tab>   <Esc>:tabnext<LF>
inoremap <C-t>     <Esc>:tabnew<LF>

" Yanks go on clipboard
set clipboard+=unnamed
set clipboard+=unnamedplus

" Open new split below or vsplit right
set splitbelow
set splitright

" set statusline
" set statusline=%t

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Enable syntax highlighting
set t_Co=256
highlight Pmenu ctermfg=2 gui=bold
highlight Pmenu ctermbg=238 gui=bold
filetype off "off reqiured by Vundle
filetype plugin indent on
syntax enable
syntax on
highlight SpellBad cterm=underline ctermfg=darkred ctermbg=None

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Use spaces instead of tabs
set expandtab
" Be smart when using tabs
set smarttab

" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4

set autoindent "Auto indent
set smartindent "Smart indent
set wrap "Wrap lines
set backspace=indent,eol,start

" Formatting turn off automatic comment on o, O and enter
autocmd FileType * setlocal formatoptions-=ro

" Source the vimrc file after saving it
"autocmd BufWritePost .vimrc source $MYVIMRC
" Fast edit the .vimrc file using ',x'
nnoremap <Leader>x :tabedit $MYVIMRC<LF>

" Return to last edit position when opening files (You want this!)
autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif

" Delete trailing white space on save, useful for Python and CoffeeScript
func! FixWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
  set ff=unix
  retab
endfunc
autocmd BufWrite *.py :call FixWS()
autocmd BufWrite *.xml :call FixWS()
autocmd BufWrite *.java :call FixWS()
autocmd BufWrite *.js :call FixWS()
autocmd BufWrite *.coffee :call FixWS()
nnoremap <Leader>fs :call FixWS()<LF>
"autocmd BufWrite *.* :call FixWS()

" autocmd FileType xml exe ':silent 1,$!XMLLINT_INDENT='    ' xmllint --format --recover - 2>/dev/null'
" autocmd FileType xml exe '$!XMLLINT_INDENT='    ' xmllint --format -'
" func! FormatXML()
"   exe $!XMLLINT_INDENT='    ' xmllint --format -"
" endfunc
" autocmd BufWrite *.xml :call FormatXML()

autocmd FileType xml exe "let &l:equalprg='xmllint --format -'"

:autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
:highlight ExtraWhitespace ctermbg=red guibg=red
:match ExtraWhitespace /\s\+$/

set pastetoggle=<F2>
set number

" Cool tab completion stuff
set wildmode=longest,list,full
set wildmenu

" Enable mouse support in console
set mouse=n

" Show tabs and trailing whitespace
set listchars=tab:▸-,trail:·,
set list

" plugins
" Vundle
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle 'gmarik/vundle'
" Bundles
Bundle 'Valloric/YouCompleteMe'
Bundle 'bling/vim-airline'
Bundle 'rosenfeld/conque-term'
Bundle 'scrooloose/nerdcommenter'
Bundle 'scrooloose/nerdtree'
Bundle 'scrooloose/syntastic'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-repeat'
Bundle 'tpope/vim-surround'
" Colors
Bundle 'Lokaltog/vim-distinguished'
Bundle 'altercation/vim-colors-solarized'
Bundle 'desert256.vim'
Bundle 'nanotech/jellybeans.vim'
Bundle 'tpope/vim-vividchalk'

" plugin mappings
nmap <F3> :NERDTreeToggle<LF>
nmap <F4> :SyntasticToggleMode<LF>

" airline plugin
set laststatus=2
set ttimeoutlen=50
set timeoutlen=5000
set noshowmode
let g:bufferline_echo = 0
let g:airline_powerline_fonts = 1

" syntastic
let g:syntastic_python_checkers=['pyflakes', 'python']
let g:syntastic_mode_map = { 'mode': 'passive',
                           \ 'active_filetypes': [],
                           \ 'passive_filetypes': [] }
let g:syntastic_warning_symbol="⚠"
let g:syntastic_error_symbol="✗"
let g:syntastic_enable_signs=1
"let g:syntastic_python_pylint_args='-d C0301,C0111,R0903 -f parseable -r n -i y'

