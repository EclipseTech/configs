"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sets how many lines of history VIM has to remember
set history=100000

" tell it to use an undo file
set undofile
" set a directory to store the undo history
set undodir=~/.vimundo/

" don't try to be compatible with vi
set nocompatible

" don't backup with ~ files
set nobackup

" :shell will bring up bash shell
set shell=bash

" set defualt file encoding
set encoding=utf-8

" Set to auto read when a file is changed from the outside
set autoread

" For regular expressions turn magic on
set magic

" map leader from \ to ,
let mapleader=','
let maplocalleader='\'

" Yanks go on clipboard if clipboard is enabled
set clipboard+=unnamed
set clipboard+=unnamedplus

" Open new split below or vsplit right
set splitbelow
set splitright

" set paste mode to F2
set pastetoggle=<F2>

" Tab completion for command line
set wildmode=longest,list,full
set wildmenu

" Enable mouse support in console mode
set mouse=n

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Navigation
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" allows moving beyond eol
set virtualedit=all

" tab navigation like firefox
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
autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif

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

" Better indentation
set autoindent
set smartindent
" Wrap lines
set wrap
set backspace=indent,eol,start

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Formatting
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Formatting turn off automatic comment on o, O and enter
autocmd FileType * setlocal formatoptions-=r
autocmd FileType * setlocal formatoptions-=o

" Delete trailing whitespace on save
func! FixWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
  set ff=unix
  retab
endfunc
" Fix whitespace on these extensions
autocmd BufWrite *.py :call FixWS()
autocmd BufWrite *.xml :call FixWS()
autocmd BufWrite *.java :call FixWS()
autocmd BufWrite *.js :call FixWS()
autocmd BufWrite *.coffee :call FixWS()
" ,fs to fix whitespace on other extensions
nnoremap <Leader>fs :call FixWS()<LF>
"autocmd BufWrite *.* :call FixWS()

" xmllint formatting options for xml filetypes
autocmd FileType xml exe "let &l:equalprg='xmllint --format -'"

" Show eol whitespace in red
:autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
:highlight ExtraWhitespace ctermbg=red guibg=red
:match ExtraWhitespace /\s\+$/

" Show tabs and trailing whitespace
set listchars=tab:>-,trail:.,
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

" show line numbers
set number

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugins
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Vundle
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle 'gmarik/vundle'
" Bundles
Bundle 'nvie/vim-flake8'
Bundle 'rosenfeld/conque-term'
Bundle 'scrooloose/nerdcommenter'
Bundle 'scrooloose/nerdtree'
Bundle 'scrooloose/syntastic'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-repeat'
Bundle 'tpope/vim-surround'
"Bundle 'Valloric/YouCompleteMe'
"Bundle 'bling/vim-airline'
" Colors
Bundle 'Lokaltog/vim-distinguished'
Bundle 'altercation/vim-colors-solarized'
Bundle 'desert256.vim'
Bundle 'nanotech/jellybeans.vim'
Bundle 'tpope/vim-vividchalk'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugin settings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" plugin mappings
nmap <F4> :SyntasticToggleMode<LF>
nmap <F5> :NERDTreeToggle<LF>

" airline plugin
"set laststatus=2
"set ttimeoutlen=50
"set timeoutlen=5000
"set noshowmode
"let g:bufferline_echo = 0
"let g:airline_powerline_fonts = 1
"let g:Powerline_symbols = "fancy"
"if !exists('g:airline_symbols')
  "let g:airline_symbols = {}
"endif
"let g:airline_symbols.space = "\ua0"
"set guifont=MyFont\ for\ Powerline

" syntastic
let g:syntastic_python_checkers=['pylint', 'pyflakes', 'python', 'flake8']
let g:syntastic_mode_map = { 'mode': 'passive',
                           \ 'active_filetypes': [],
                           \ 'passive_filetypes': [] }
let g:syntastic_warning_symbol="!"
let g:syntastic_error_symbol="X"
let g:syntastic_enable_signs=1

" vim-flake8
"let g:flake8_ignore=""
"let g:flake8_max_line_length=80
"autocmd BufWritePost *.py call Flake8() " run flake8 on python file on write

