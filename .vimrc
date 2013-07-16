"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sets how many lines of history VIM has to remember
set history=700

set nocompatible " don't try to be compatible with vi

set nobackup

set virtualedit=all

" Set to auto read when a file is changed from the outside
set autoread

" Always show current position
set ruler

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Highlight search results
set hlsearch
" set incsearch

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch

" Set statusline
" set statusline=%t

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Enable syntax highlighting
filetype on
filetype plugin on
syntax enable
syn on
" Autocompletion
" set omnifunc=syntaxcomplete#Complete

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

set ai "Auto indent
set si "Smart indent
set wrap "Wrap lines
set backspace=indent,eol,start

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
autocmd BufWrite *.* :call FixWS()

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
"set mouse=a

" Show tabs and trailing whitespace
set listchars=tab:▸-,trail:·,
set list

