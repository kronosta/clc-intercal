package Language::INTERCAL::Listing::html;

# Plain text source listings

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Carp;

use Language::INTERCAL::Listing;

use vars qw($VERSION $PERVERSION @ISA);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Listing/html.pm 1.-94.-2.3") =~ /\s(\S+)$/;

@ISA = qw(Language::INTERCAL::Listing);

use constant default_suffix => 'html';

# XXX we ought to get this list from the compiler itself
my @highlight = (
    ['DO_PLEASE',        'em',     'prefix'],
    ['QUALIFIERS',       'em',     'modifier'],
    ['MAYBE_ONCE',       'em',     'modifier'],
    ['EXPRESSION',       'strong', 'expression'],
    ['EXP_OR_DIM',       'strong', 'expression'],
    ['BINARY',           'strong', 'operator'],
    ['BINARIES',         'strong', 'operator'],
    ['UNARY',            'strong', 'operator'],
    ['UNARIES',          'strong', 'operator'],
    ['E_LIST',           'strong', 'operator'],
    ['NAMES',            'strong', 'operator'],
    ['RABBIT',           'strong', 'operator'],
    ['BELONG',           'strong', 'operator'],
    ['SUBSCRIPT',        'strong', 'operator'],
    ['REGISTER',         'strong', 'register'],
    ['LELEMENT',         'strong', 'register'],
    ['ELEMENT',          'strong', 'register'],
    ['BANG',             'strong', 'register'],
    ['LVALUE',           'strong', 'register'],
    ['ARRAY',            'strong', 'register'],
    ['NONUNARIES',       'strong', 'constant'], # XXX this needs special processing
    ['STMT_LABEL',       'strong', 'label'],
    ['VERB',             'em',     'statement'],
    [qr/^Q_/,            'em',     'quantum'],
);

sub prepare {
    @_ == 2 or croak "Usage: LISTING->prepare(OBJECT)";
    my ($ls, $obj) = @_;
    my $table = $obj->symboltable;
    my (%symbols, %names);
    for my $hl (@highlight) {
	if (ref $hl->[0]) {
	    for my $s ($table->grep($hl->[0])) {
		$symbols{$s->[0]} = [$s->[1], $hl->[1], $hl->[2]];
		$names{$s->[1]} = undef;
	    }
	} else {
	    my $s = $table->find($hl->[0]);
	    if ($s) {
		$symbols{$s} = $hl;
		$names{$hl->[0]} = undef;
	    }
	}
    }
    # $ls->[0] is set by Listing.pm and contains the argument
    $ls->[1] = \%symbols;
    $obj->parser(1)->start_recording([keys %names]);
    $ls;
}

sub list {
    @_ == 4 or croak "Usage: LISTING->list(SOURCE, OBJECT, FILENAME)";
    my ($ls, $src, $obj, $filename) = @_;
    # extract information we need
    my $table = $obj->symboltable;
    my $highlight = $ls->[1];
    my $rec = $obj->parser(1)->syntax_record;
    my $fh = Language::INTERCAL::GenericIO->new('FILE', 'r', $filename);
    my $emit_prefix = 1;
    my $pos = 0;
    while ($pos < length $src) {
	my @annotate;
	my $comment = [0, 'em', 'comment'];
	# XXX this ought to come from grammar
	pos($src) = $pos;
	if ($src =~ /\G(\s*(?:do|please|please\s*do)\s*note:\s*\S)/gi) {
	    $comment->[0] = $pos + length($1);
	} elsif (exists $rec->{$pos}) {
	    # find longest valid prefix but ignore comments
	    my @end = sort { $b <=> $a }
		      grep { $_ && ref $rec->{$pos}{$_} }
		      keys %{$rec->{$pos}};
	    PROD: while (@end) {
		my $end = shift @end;
		for my $item (@{ $rec->{$pos}{$end}}) {
		    my ($symbol, $bad, $tree) = @$item;
		    $bad and next;
		    if ($tree) {
			# normal case, a production
			my @stack = ([$pos, $end, $symbol, $tree]);
			my @ann;
			while (@stack) {
			    my ($sp, $ep, $sy, $tr) = @{pop @stack};
			    if ($sy && $highlight->{$sy}) {
				my $w = $sp;
				my $a = $highlight->{$sy};
				$ann[$w++] = $a while $w < $ep;
			    }
			    $tr or next;
			    push @stack, @$tr;
			}
			# now fill up @annotate based on @ann
			my $where = 0;
			while ($where < @ann) {
			    my $start = $where;
			    my $item = $ann[$where++];
			    while ($where < @ann) {
				my $n = $ann[$where];
				$item && ! $n and last;
				$n && ! $item and last;
				$n && $n != $item and last;
				$where++;
			    }
			    $item and push @annotate, ([$start, $where, $item]);
			}
		    } else {
			# special case, this was matched by a built-in symbol
			my $ann = $highlight->{$item};
			$ann and push @annotate, [$pos, $end, $ann];
		    }
		    $comment = undef;
		    last PROD;
		}
	    }
	}
	# if the previous code hasn't found any annotation, we treat it as a
	# comment, annotate it and skip it; if it's the first comment before
	# emitting anything, we also check if it contains the description
	# to use as HTML title
	if (! @annotate) {
	    my $next = $comment && $comment->[0] ? $comment->[0] : $pos;
	    my @next = sort { $a <=> $b } grep { $_ > $next } keys %$rec;
	    $next = @next ? $next[0] : length $src;
	    if ($emit_prefix && $comment) {
		my $title = substr($src, $pos, $next - $pos);
		# XXX this ought to come from grammar
		if ($title =~ s/^\s*(?:do|please|please\s*do)\s*note:\s*(\S)/$1/i) {
		    $title =~ s/^\s+//;
		    $title =~ s/\n\n.*$//s;
		    $title =~ s/\s+$//;
		    $title =~ s/\s+/ /g;
		    $ls->html_prefix($fh, $title);
		    $emit_prefix = 0;
		}
	    }
	    @annotate = ([$pos, $next, $comment]);
	}
	# OK, emit this
	if ($emit_prefix) {
	    $emit_prefix = 0;
	    $ls->html_prefix($fh); # program has no "title" comments
	}
	for my $ap (@annotate) {
	    my ($where, $next, $item) = @$ap;
	    $next > length $src and $next = length $src;
	    $item or $where = $next;
	    $pos < $where and $ls->html_text($fh, substr($src, $pos, $where - $pos));
	    if ($where < $next) {
		my ($name, $tag, $style) = @$item;
		my $text = substr($src, $where, $next - $where);
		for my $line (split(/(\n+)/, $text)) {
		    # XXX would probably want to use the "space" symbol to do this
		    $line =~ s/^(\s+)// and $ls->html_text($fh, $1);
		    my $eol = '';
		    $line =~ s/(\s+)$// and $eol = $1;
		    $line ne '' and $ls->html_style($fh, $line, $tag, $style);
		    $eol ne '' and $ls->html_text($fh, $eol);
		}
	    }
	    $pos = $next;
	    pos($src) = $pos;
	    # XXX and of course this too
	    if ($src =~ /\G(\s+)/g) {
		$pos = pos($src);
		$ls->html_text($fh, $1);
	    }
	}
    }
    $pos < length $src and $ls->html_text($fh, substr($src, $pos));
    $ls->html_footer($fh);
}

sub html_prefix {
    my ($ls, $fh, $title) = @_;
    $fh->read_text("<html>\n");
    $fh->read_text("<head>\n");
    if ($ls->[0]) {
	$fh->read_text("<link rel=\"stylesheet\" type=\"text/css\" href=\"$ls->[0]\" />\n");
    }
    if (defined $title) {
	$fh->read_text("<title>");
	$ls->html_text($fh, $title);
	$fh->read_text("</title>\n");
    }
    $fh->read_text("</head>\n");
    $fh->read_text("<body>\n");
    if ($ls->[0]) {
	$fh->read_text("<pre class=\"clc-intercal\">\n");
    } else {
	$fh->read_text("<pre>\n");
    }
}

sub html_footer {
    my ($ls, $fh) = @_;
    $fh->read_text("</pre>\n");
    $fh->read_text("</body>\n");
    $fh->read_text("</html>\n");
}

sub html_text {
    my ($ls, $fh, $text) = @_;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $fh->read_text($text);
}

sub html_style {
    my ($ls, $fh, $text, $tag, $style) = @_;
    if ($ls->[0]) {
	$fh->read_text("<$tag class=\"$style\">");
    } else {
	$fh->read_text("<$tag>");
    }
    $ls->html_text($fh, $text);
    $fh->read_text("</$tag>");
}

1;
