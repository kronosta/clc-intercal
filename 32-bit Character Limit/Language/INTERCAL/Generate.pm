package Language::INTERCAL::Generate;

# Creates automatically generated files (ByteCode, Splats) from descriptions

# This file is part of CLC-INTERCAL

# Copyright (c) 2007-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# Usage: perl -MLanguage::INTERCAL::Generate \
#           -e 'Language::INTERCAL::Generate::Generate()' [INPUT [OUTPUT]]

# If a file contains the string @@SKIPME@@ this module just copies it unchanged,
# in particular when it processes itself it doesn't make any changes because
# of this comment.

# INPUT (or standard input) can contain the following commands to generate
# data-dependent lines:

# @@DATA filename@@
# loads filename as a data SPEC (see below)

# (prefix)@@VERSION@@(suffix)
# replaces @@VERSION@@ with the data version number

# (prefix)@@FILL GROUP PRE FIELD POST SIZE SEP@@(suffix)
# fills a line with as many elements from GROUP as possible, then repeats
# with another line until all elements of GROUP have been listed; each
# element will be taken from the given FIELD and the line lenght will
# not exceed SIZE. (prefix) and (suffix) are added at the start and
# the end of each line generated; PRE and POST are added before and
# after each element; SEP is added between elements in the same line.
# The data is sorted by the given FIELD. For example:
# [@@FILL SPLATS 'SP_' NAME '' 76 '/'@@]
# may generate:
# [SP_BCMATCH/SP_CHARSET/SP_CIRCULAR/SP_COMMENT/SP_CREATION/SP_DIGITS]
# [SP_INVALID/SP_IOTYPE/SP_JUNK/SP_NONUMBER/SP_NOSUCHCHAR/SP_ROMAN/SP_SPOTS]
# [SP_THREESPOT/SP_TODO]

# (prefix)@@ALL GROUP FIELD@@(suffix)
# generates as many lines as there are elements of GROUP; each line is
# generated by replacing any @@FIELD@@ in (prefix) and (suffix) with
# the corresponding data, and replacing the @@ALL...@@ with the
# value of FIELD. The data is sorted by the FIELD. For example:
# [@@NUMBER@@ SP_@@ALL SPLATS NAME@@]
# may generate:
# [578 SP_BCMATCH]
# ...
# [1 SP_TODO]
# to insert a literal whirlpool where this can cause confusion use
# @@WHIRLPOOL@@. Note that if your GROUP has a field named WHIRLPOOL
# this will not be accessible.

# @@MULTI GROUP FIELD@@
# (content)
# I@MULTI@@
# is a multiline version of @@ALL...@@: produces a block for each
# element of group, sorted by FIELD, in which each line of (content)
# is subject to the same substitution rules as @@ALL@@. Does not
# automatically insert the FIELD in the output, use @@FIELD@@ for
# that. A special syntax @@FIELD SIZE@@ "folds" FIELD: for a multiline
# field containing blank lines, each block is folded separately.

# (prefix)@@ARRAY GROUP FIELD@@(suffix)
# GAPS
# Works identically to @@ALL...@@ except that FIELD must be numeric and
# any gaps in the numbering will be replaced by GAPS rather than expanding
# the line (note that GAPS is provided in the line immediately following
# @@ARRAY@@): for example to initialise an array of statement opcodes one
# could say:
# my @statements = (
#     \&stmt_@@NAME@@, # @@ARRAY STATEMENTS NUMBER@@
#     undef, # @@NUMBER@@
# );

# @@FIRST GROUP FIELD@@
# @@LAST GROUP FIELD@@
# First and last element in field FIELD of GROUP, under normal sorting;
# it can be used to determine the range of values produced by @@ARRAY...@@

# @@LINE@@
# The line number in the original source. This can be used for example
# to make sure that perl's error and warning messages refer to the line
# of the unconverted file which is the one would edit

# SPEC contains data specification in the form:
# @GROUP NAME FIELD...
# DATA
# @END [NAME]

# Each FIELD definition has the form NAME=TYPE where TYPE is m (multiline),
# 'd' (digits), 's' (string), 'w' (word) or '@TYPE' (array - cannot be
# used for multiline).

# Each line of DATA is one record followed by the contents of a multiline
# field, if present; alternatively the special line @SOURCE GROUP will
# include the whole of another group and @GREP GROUP FIELD=VALUE will
# include just the matching elements. The contents of the multiline field
# must be more indented than the record they refer to and than the record
# that follows, for example:
#   DATA
#      multiline 1
#      multiline 2
#     muitiline 3
#  NEXT RECORD
# if a line in a multiline field starts with # it will be interpreted as
# a comment and ignored; if it starts with @ it will be interpreted as
# an escape (e.g. @END). These can be escaped with a backslash, which
# will be removed from the beginning of line. Note that backslashes
# anywhere else in the multiline fields are not touched.
# All lines in a multiline field will be joined together, separated by
# a single space (the above sequence produces "multiline 1 multiline 2
# multiline 3"), except a blank line which produces a double newline
# in the field.

use strict;

use Carp;
use File::Spec;

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Generate.pm 1.-94.-2.3") =~ /\s(\S+)$/;

if ($ENV{CLC_INTERCAL_BUNDLE} && $ENV{CLC_INTERCAL_BUNDLE} eq '42' && $ENV{CLC_INTERCAL_ROOT}) {
    my $exporter = File::Spec->catfile($ENV{CLC_INTERCAL_ROOT}, qw(INTERCAL Exporter.pm));
    eval "require '$exporter'"; $@ and die $@;
} else {
    require Language::INTERCAL::Exporter;
}
import Language::INTERCAL::Exporter qw(is_intercal_number compare_version);

my $data_suffix = '.Data';
my %groups;

sub Generate {
    @ARGV >= 0 && @ARGV <= 2 or croak "Usage: Generate [INPUT [OUTPUT]]";
    my ($input, $output) = @ARGV;

    %groups = ();

    # translate INPUT into OUTPUT
    @ARGV = defined $input ? ($input) : ();
    if (defined $output) {
	open(STDOUT, '>', $output)
	    or die "$output: $!";
    }
    my $skipme = 0;
    my $data_version = '';
    while (<>) {
	my $orig = $_;
	if (/\@\@SKIPME\@\@/) {
	    $skipme = 1;
	}
	if ($skipme) {
	    print;
	    next;
	}
	s/\@\@LINE\@\@/$./g;
	s/\@\@VERSION\@\@/$data_version/g;
	if (/^\s*\@\@DATA\s+(.*?)\@\@$/) {
	    load_spec($1 . $data_suffix, \$data_version);
	    next;
	}
	if (s/^(.*)\@\@FILL\s*//) {
	    my $line_pre = $1;
	    my $group = get_field($orig, \$_, 'w');
	    exists $groups{$group}
		or die "Unknown group $group";
	    my $gp = $groups{$group};
	    my $item_pre = get_field($orig, \$_, 's');
	    my $item_name = get_field($orig, \$_, 'w');
	    exists $gp->{fpos}{$item_name}
		or die "Unknown field $item_name in group $group";
	    my $item_pos = $gp->{fpos}{$item_name};
	    my $item_post = get_field($orig, \$_, 's');
	    my $line_size = get_field($orig, \$_, 'd');
	    my $item_sep = get_field($orig, \$_, 's');
	    s/^\@\@// or die "Missing \@\@ after \@\@FILL";
	    my $line_post = $_;
	    my @il = sort_items($item_pos, $gp->{data});
	    my $line = $line_pre;
	    for my $item (@il) {
		my $nl = $line;
		$nl .= $item_sep if $nl ne $line_pre;
		$nl .= $item_pre . $item . $item_post;
		if (sizeof($nl . $line_post) > $line_size) {
		    print $line, $line_post if $line ne $line_pre;
		    $nl = $line_pre . $item_pre . $item . $item_post;
		}
		$line = $nl;
	    }
	    print $line, $line_post if $line ne $line_pre;
	    next;
	}
	if (s/^(.*)\@\@(ALL|ARRAY)\s*//) {
	    my $line_pre = $1;
	    my $is_array = $2 eq 'ARRAY';
	    my $group = get_field($orig, \$_, 'w');
	    exists $groups{$group}
		or die "Unknown group $group";
	    my $gp = $groups{$group};
	    my $item_name = get_field($orig, \$_, 'w');
	    exists $gp->{fpos}{$item_name}
		or die "Unknown field $item_name in group $group";
	    my $item_pos = $gp->{fpos}{$item_name};
	    s/^\@\@// or die "Missing \@\@ after \@\@ALL";
	    my $line_post = $_;
	    my @il = sort_items($item_pos, $gp->{data});
	    my $p = $gp->{fpos};
	    check_escapes($gp, $p, $line_pre);
	    check_escapes($gp, $p, $line_post);
	    my ($gaps, $gregex);
	    if ($is_array) {
		$gaps = <>;
		defined $gaps or die "Missing line after \@\@ARRAY,,,\@\@";
		$gregex = qr/\@\@$item_name\@\@/;
	    }
	    my $next = 0;
	    while (@il) {
		my $il = shift @il;
		if ($is_array) {
		    while ($next < $il) {
			my $il = $gaps;
			$il =~ s/$gregex/$next/g;
			print $il;
			$next++;
		    }
		    $next++;
		}
		my @items = grep { $_->[$item_pos] eq $il } @{$gp->{data}};
		@items or die "Internal error: $il not found";
		@items == 1 or die "Invalid group, duplicate $il";
		my $item = $items[0];
		my $prn = '';
		for my $ol ($line_pre, $il, $line_post) {
		    my $line = $ol;
		    my $trans = '';
		    while ($line =~ s/^(.*?)\@\@//) {
			$trans .= $1;
			$line =~ s/^(.*?)\@\@//
			    or die "Missing \@\@ closing $line";
			my $gn = $1;
			my $quote = $gn =~ s/^(['"]?)(\w+)\1$/$2/ ? $1 : '';
			my %tran;
			while ($gn =~ s/\s+TRAN(.)(.)$//i) {
			    $tran{$1} = $2;
			}
			my $tran;
			if (keys %tran) {
			    $tran = join('', keys %tran);
			    $tran = qr/([$tran])/;
			}
			my $f;
			if ($gn eq 'WHIRLPOOL') {
			    $f = '@';
			} elsif ($gn =~ /^(.*?):(\w+)$/) {
			    if ($item) {
				$f = $item->[$p->{$1}];
				my @a = @{$item->[$p->{$2}]};
				$f =~ s/%/shift @a || '???'/ge;
			    } else {
				$f = $gaps;
			    }
			} else {
			    if ($item) {
				$f = $item->[$p->{$gn}];
				if ($tran) {
				    $f =~ s/$tran/$tran{$1}/ge;
				}
			    } else {
				$f = $gaps;
			    }
			}
			$f =~ s/([\\$quote])/\\$1/g if $quote ne '';
			$trans .= $f;
		    }
		    $prn .= $trans . $line;
		}
		print $prn;
	    }
	    next;
	}
	if (s/^\s*\@\@MULTI\s*//) {
	    my $group = get_field($orig, \$_, 'w');
	    exists $groups{$group}
		or die "Unknown group $group";
	    my $gp = $groups{$group};
	    my $item_name = get_field($orig, \$_, 'w');
	    exists $gp->{fpos}{$item_name}
		or die "Unknown field $item_name in group $group";
	    my $item_pos = $gp->{fpos}{$item_name};
	    s/^\@\@\s*$// or die "Missing \@\@ after \@\@MULTI";
	    my @il = sort_full($item_pos, $gp->{data});
	    my $p = $gp->{fpos};
	    my @line = ();
	    my $found = 0;
	    while (<>) {
		if (/^\s*\@\@MULTI\@\@\s*$/) {
		    $found = 1;
		    last;
		}
		push @line, $_;
		check_escapes($gp, $p, $_);
	    }
	    $found or die "Missing \@\@MULTI\@\@";
	    for my $il (@il) {
		print translate_escapes($gp, $p, $il, $_) for @line;
	    }
	    next;
	}
	if (s/^(.*?)\@\@(FIRST|LAST)\s*//) {
	    my $line_pre = $1;
	    my $what = $2;
	    $line_pre =~ /\@\@/ and die "Cannot have more \@\@-escapes with \@\@$what";
	    my $index = $what eq 'FIRST' ? 0 : -1;
	    my $group = get_field($orig, \$_, 'w');
	    exists $groups{$group}
		or die "Unknown group $group";
	    my $gp = $groups{$group};
	    my $item_name = get_field($orig, \$_, 'w');
	    exists $gp->{fpos}{$item_name}
		or die "Unknown field $item_name in group $group";
	    my $item_pos = $gp->{fpos}{$item_name};
	    s/^\@\@// or die "Missing \@\@ after \@\@$what";
	    /\@\@/ and die "Cannot have more \@\@-escapes with \@\@$what";
	    my $line_post = $_;
	    my @il = sort_full($item_pos, $gp->{data});
	    print $line_pre, $il[$index][$item_pos], $line_post;
	    next;
	}
	if (/\@\@/) {
	    chomp;
	    die "Invalid \@\@-escape: $_";
	}
	print;
    }
}

sub get_field {
    my ($orig, $line, $type) = @_;
    if ($type =~ s/^\@//) {
	$$line =~ s/^\[\s*//
	    or die "Invalid array: missing [";
	my @data = ();
	while ($$line ne '' && $$line !~ s/^\]\s*//) {
	    push @data, get_field($orig, $line, $type);
	}
	return \@data;
    }
    if ($type eq 'd') {
	$$line =~ s/^0x([[:xdigit:]]+)\s*//
	    and return hex($1);
	$$line =~ s/^(\d+)\s*//
	    and return $1;
	die "Invalid number: $_";
    }
    if ($type eq 'w') {
	$$line =~ s/^(\w+)\s*//
	    or die "Invalid symbol: $_";
	return $1;
    }
    if ($type eq 's') {
	if ($$line =~ s/^(['"])//) {
	    # quoted string
	    my $quote = $1;
	    my $data = '';
	    while ($$line =~ s/^(.*?)([$quote\\])//) {
		$data .= $1;
		last if $2 eq $quote;
		die "Invalid data: \\ at end of line" if $$line eq '';
		$data .= substr($$line, 0, 1, '');
	    }
	    $$line =~ s/^\s+//;
	    return $data;
	} else {
	    # bareword
	    $$line =~ s/^(\S+)\s*//
		or die "Invalid string: $_";
	    return $1;
	}
    }
    die "Internal error: type is '$type'";
}

sub sizeof {
    my ($s) = @_;
    my $l = 0;
    while ($s ne '') {
	my $x = substr($s, 0, 1, '');
	if ($x eq "\t") {
	    $l = 8 * (1 + int($l / 8));
	} else {
	    $l++;
	}
    }
    $l;
}

sub sort_full {
    my ($pos, $arr) = @_;
    sort {
	return $a->[$pos] <=> $b->[$pos] if $a->[$pos] =~ /^\d+$/ && $b->[$pos] =~ /^\d+$/;
	return -1 if $a->[$pos] =~ /^\d+$/;
	return  1 if $b->[$pos] =~ /^\d+$/;
	return $a->[$pos] cmp $b->[$pos];
    } @$arr;
}

sub sort_items {
    my ($pos, $arr) = @_;
    sort {
	return $a <=> $b if $a =~ /^\d+$/ && $b =~ /^\d+$/;
	return -1 if $a =~ /^\d+$/;
	return  1 if $b =~ /^\d+$/;
	return $a cmp $b;
    } map { $_->[$pos] } @$arr;
}

sub field_map {
    my ($a, $b) = @_;
    # we are trying to append $b's data to $a...
    my @map = ();
    for my $n (@{$b->{fnames}}) {
	# $a must have this field
	return () if ! exists $a->{fpos}{$n};
	# the fields must have the same type
	return () if $a->{ftypes}{$n} ne $b->{ftypes}{$n};
	my $p = $a->{fpos}{$n};
	push @map, $p;
    }
    @map;
}

sub check_escapes {
    my ($gp, $p, $line) = @_;
    while ($line =~ s/^.*?\@\@//) {
	$line =~ s/^(.*?)\@\@//
	    or die "Missing \@\@ closing $line";
	my $gn = $1;
	$gn =~ s/\s+HTML$//i;
	1 while $gn =~ s/\s+TRAN..$//i;
	$gn =~ s/\s+\d+$//;
	next if $gn eq 'WHIRLPOOL';
	my $ogn = $gn;
	if ($gn =~ s/^(\w+(?:%[^sd]*[sd])?):(\w+)\s*//) {
	    my $next = $gn;
	    $gn = $1;
	    exists $p->{$2}
		or die "Invalid field name $2";
	    substr($gp->{ftypes}{$2}, 0, 1) eq '@'
		or die "Field $2 is not an array";
	    my $mapfrom = get_field($ogn, \$next, 's');
	    my $prefix = get_field($ogn, \$next, 's');
	    my $suffix = get_field($ogn, \$next, 's');
	}
	$gn =~ s/^(['"])(.*)\1$/$2/;
	$gn =~ s/%[^sd]*[sd]$//;
	exists $p->{$gn}
	    or die "Invalid field name $gn\n";
    }
}

sub translate_escapes {
    my ($gp, $p, $item, $line) = @_;
    my $trans = '';
    while ($line =~ s/^(.*?)\@\@//) {
	$trans .= $1;
	$line =~ s/^(.*?)\@\@//;
	my $gn = $1;
	if ($gn eq 'WHIRLPOOL') {
	    $trans .= '@';
	    next;
	}
	my $html = $gn =~ s/\s+HTML$//i;
	my %tran;
	while ($gn =~ s/\s+TRAN(.)(.)$//i) {
	    $tran{$1} = $2;
	}
	my $tran;
	if (keys %tran) {
	    $tran = join('', keys %tran);
	    $tran = qr/([$tran])/;
	}
	my $fold = $gn =~ s/\s+(\d+)$// ? $1 : undef;
	my ($mapfrom, $prefix, $suffix, $mapto);
	my $format = '%s';
	my $ogn = $gn;
	if ($gn =~ s/^(\w+(?:%[^sd]*[sd])?):(\w+)\s*//) {
	    my $next = $gn;
	    $gn = $1;
	    $mapto = $2;
	    $mapfrom = get_field($ogn, \$next, 's');
	    $prefix = get_field($ogn, \$next, 's');
	    $suffix = get_field($ogn, \$next, 's');
	}
	$gn =~ s/(%[^sd]*[sd])$// and $format = $1;
	my $quote = $gn =~ s/^(['"]?)(\w+)\1$/$2/ ? $1 : '';
	my $f = $item->[$p->{$gn}];
	if (defined $mapto) {
	    my @a = @{$item->[$p->{$mapto}]};
	    $f =~ s/$mapfrom/$prefix . (shift @a || '???'). $suffix/ge;
	}
	$f = sprintf $format, $f;
	if ($tran) {
	    $f =~ s/$tran/$tran{$1}/ge;
	}
	if ($html) {
	    $f =~ s/&/&amp;/gi;
	    $f =~ s/</&lt;/gi;
	    $f =~ s/>/&gt;/gi;
	    $f =~ s/"/&quot;/gi;
	    $f =~ s/I&lt;([[:upper:]]{3})&gt;/<A HREF="#op$1"><I>$1<\/I><\/A>/g;
	    $f =~ s/I&lt;\%([[:upper:]]{2})&gt;/<A HREF="#dos$1"><I>%$1<\/I><\/A>/g;
	    $f =~ s/I&lt;\^([[:upper:]]{2})&gt;/<A HREF="#shf$1"><I>^$1<\/I><\/A>/g;
	    $f =~ s/I&lt;\@([[:upper:]]{2})&gt;/<A HREF="#whp$1"><I>\@$1<\/I><\/A>/g;
	    $f =~ s/I&lt;(.*?)&gt;/<I>$1<\/I>/gi;
	    $f =~ s/L&lt;Language::INTERCAL::Charset&gt;/<A HREF="charset.html">the chapter on character sets<\/A>/gi;
	    $f =~ s/L&lt;Language::INTERCAL::(?:ArrayIO|ReadNumber|WriteNumber)&gt;/<A HREF="input_output.html">the chapter on Input\/Output<\/A>/gi;
	    $f =~ s/L&lt;(.*?)&gt;/<CODE>$1<\/CODE>/gi;
	    $f =~ s/C&lt;(.*?)&gt;/<CODE>$1<\/CODE>/gi;
	    $f =~ s/\n\n+/<BR>/g;
	}
	if (defined $fold) {
	    my $u = $f;
	    $f = '';
	    my $next_indent = '';
	    $trans =~ /^(\s+)/ and $next_indent = $1;
	    my $indent = '';
	    for my $o (split(/\n\n/, $u)) {
		$o =~ /^(\s+)/ and $indent = $1;
		while (sizeof($o) > $fold) {
		    my $g = '';
		    while ($o =~ s/^(\S*)(\s+)//) {
			my ($n, $s) = ($1, $2);
			if (sizeof($g . $n) > $fold) {
			    $o = $n . $s . $o;
			    last;
			}
			$g .= $n . $s;
		    }
		    $g =~ s/\s+$//;
		    $f .= $indent . $g . "\n";
		    $indent = $next_indent;
		}
		$f .= $indent . $o . "\n\n";
		$indent = $next_indent;
	    }
	    $f =~ s/\n\n$//;
	}
	$f =~ s/([\\$quote])/\\$1/g if $quote ne '';
	$trans .= $f;
    }
    $trans .= $line;
    $trans;
}

sub load_spec {
    my ($dataname, $max_version) = @_;
    my $dataspec;
    if ($ENV{CLC_INTERCAL_BUNDLE} && $ENV{CLC_INTERCAL_BUNDLE} eq '42' && $ENV{CLC_INTERCAL_ROOT}) {
	$dataspec = File::Spec->catfile($ENV{CLC_INTERCAL_ROOT}, qw(INTERCAL Generate), $dataname);
	open(DATASPEC, '<', $dataspec) or die "$dataspec: $!\n";
    } else {
	for my $path (@INC) {
	    my $d = File::Spec->catfile($path, qw(Language INTERCAL Generate), $dataname);
	    open(DATASPEC, '<', $d) or next;
	    $dataspec = $d;
	    last;
	}
	defined $dataspec or die "$0: $dataname: $!";
    }
    print STDERR "    ($dataspec)\n";
    my $in_group = undef;
    my $item_indent = undef;
    my $last_multi = undef;
    my $blank_line = 0;
    while (<DATASPEC>) {
	chomp;
	last if /^\s*\@\__END__/;
	if (/\bPERVERSION\b.*\bGenerate\/\Q$dataname\E\s*([-\.\d]+)\b/) {
	    my $pv = $1;
	    is_intercal_number($pv) or die "$dataname: invalid PERVERSION $pv\n";
	    $$max_version eq '' || compare_version($$max_version, $pv) < 0
		and $$max_version = $pv;
	}
	if (/^\s*#|^\s*$/) {
	    $blank_line = 1;
	    next;
	}
	my $bl = $blank_line;
	$blank_line = 0;
	if (defined $in_group) {
	    if (s/^\s*\@END\s*//) {
		die "group $in_group->{name} ended by \@END $_"
		    if $in_group->{name} ne $_;
		if ($in_group->{has_m}) {
		    $_->[-1] = ${$_->[-1]} for @{$in_group->{data}};
		}
		$in_group = undef;
		next;
	    }
	    if (s/^\s*\@SOURCE\s+//) {
		push @{$in_group->{sources}}, $_;
		next;
	    }
	    if (s/^\s*\@GREP\s+(\S+)\s+//) {
		push @{$in_group->{greps}}, [$1, split];
		next;
	    }
	    die "$0: Invalid \@ escape ($_)" if /^\s*\@/;
	    my $indent = s/^([ \t]+)// ? sizeof($1) : 0;
	    if ($in_group->{has_m} &&
		defined $item_indent &&
		$item_indent < $indent)
	    {
		s/^\\//;
		if ($bl) {
		    $$last_multi .= "\n\n" if $bl;
		} elsif ($$last_multi ne '') {
		    $$last_multi .= ' ';
		}
		$$last_multi .= $_;
	    } else {
		$item_indent = $indent;
		# process group line
		my @line = ();
		for my $fname (@{$in_group->{fnames}}) {
		    my $ftype = $in_group->{ftypes}{$fname};
		    next if $ftype eq 'm';
		    push @line, get_field($_, \$_, $ftype);
		}
		die "Extra data at end of line ($_)" if $_ ne '';
		if ($in_group->{has_m}) {
		    my $x = '';
		    $last_multi = \$x;
		    push @line, $last_multi;
		}
		push @{$in_group->{data}}, \@line;
	    }
	} elsif (s/^\s*\@GROUP\s+//) {
	    my ($group, @fspec) = split;
	    die "$0: duplicate group $group" if exists $groups{$group};
	    die "$0: group $group has no fields!" unless @fspec;
	    my @fnames = ();
	    my %ftypes = ();
	    my %fpos = ();
	    my $has_m = 0;
	    for my $fs (@fspec) {
		$fs =~ /^(\w+)=(.*)$/ or die "Invalid field definition ($fs)";
		my ($name, $type) = ($1, lc($2));
		exists $ftypes{$type} and die "Duplicate field name ($name)";
		$type =~ /^(?:\@*[dws]|m)$/ or die "Invalid field type ($fs)";
		die "Sorry, multiline fields must be last" if $has_m;
		$has_m = 1 if $type eq 'm';
		$fpos{$name} = scalar @fnames;
		push @fnames, $name;
		$ftypes{$name} = $type;
	    }
	    $in_group = {
		fnames => \@fnames,
		ftypes => \%ftypes,
		fpos => \%fpos,
		data => [],
		sources => [],
		greps => [],
		name => $group,
		has_m => $has_m,
	    };
	    $groups{$group} = $in_group;
	} else {
	    die "Invalid line ($_)";
	}
    }
    close DATASPEC;

    # process SOURCE
    for my $g (values %groups) {
	for my $s (@{$g->{sources}}) {
	    $s ne $g && exists $groups{$s}
		or die "Invalid source $s for $g->{name}";
	    my $d = $groups{$s};
	    @{$d->{sources}} || @{$d->{greps}}
		and die "Sourcing from a group containing sources ($s) not implemented";
	    my @map = field_map($g, $d)
		or die "$g->{name} cannot source from $s: incompatible fields";
	    for my $d (@{$d->{data}}) {
		push @{$g->{data}}, [map { $d->[$_] } @map];
	    }
	}
	for my $gp (@{$g->{greps}}) {
	    my ($s, @f) = @$gp;
	    $s ne $g && exists $groups{$s}
		or die "Invalid grep source $s for $g->{name}";
	    my $d = $groups{$s};
	    @{$d->{sources}} || @{$d->{greps}}
		and die "Sourcing from a group containing sources ($s) not implemented";
	    my @map = field_map($g, $d)
		or die "$g->{name} cannot source from $s: incompatible fields";
	    my @v;
	    for my $f (@f) {
		$f =~ /^(\S+?)=(\S+)$/ or die "Invalid grep filter $f in $g->{name}\n";
		my ($n, $v) = ($1, $2);
		exists $d->{fpos}{$n} or die "Invalid grep filter field $n in $g->{name}\n";
		push @v, [$d->{fpos}{$n}, $v];
	    }
	DATA:
	    for my $e (@{$d->{data}}) {
		for my $vp (@v) {
		    my ($n, $v) = @$vp;
		    $e->[$n] eq $v or next DATA;
		}
		push @{$g->{data}}, [map { $e->[$_] } @map];
	    }
	}
    }
}

1;
