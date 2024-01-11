package Language::INTERCAL::Interface::Line;

# line-oriented user interface

# This file is part of CLC-INTERCAL

# Copyright (c) 2007-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/UI-Line INTERCAL/Interface/Line.pm 1.-94.-2.3") =~ /\s(\S+)$/;

BEGIN { $ENV{PERL_RL} = 'Gnu'; } # doesn't work with any other ReadLine package

use Carp;
use Term::ReadLine;
use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::GenericIO '1.-94.-2.1', qw($stdread $stdwrite);

sub new {
    @_ == 2
	or croak "Usage: Language::INTERCAL::Interface::Line->new(SERVER)";
    my ($class, $server) = @_;
    -t STDIN or die "Standard input not a terminal\n";
    $server or croak "Must provide SERVER";
    my $term = Term::ReadLine->new('CLC-INTERCAL')
	or die "Term::ReadLine: $!\n";
    $term->ReadLine eq 'Term::ReadLine::Gnu'
	or die "Sorry, only Term::ReadLine::Gnu is supported at present\n";
    my $wobj = bless {
	prompt  => ['Intercalc'],
	buffer  => '',
	server  => $server,
	term    => $term,
	stack   => [],
	convert => $stdwrite->write_convert,
    }, 'Language::INTERCAL::Interface::Line::WOBJ';
    my $infile = new Language::INTERCAL::GenericIO('OBJECT', 'w', $wobj);
    my $line = bless {
	term     => $term,
	stdwrite => $infile,
	wobj     => $wobj,
    }, $class;
    my $attribs = $term->Attribs;
    $attribs->{attempted_completion_function} = sub {
	my ($ignore, $text, $start, $end) = @_;
	my $code = $line->{complete};
	return ('') unless $code;
	my $base = substr($text, $start, $end - $start);
	$text = substr($text, 0, $end);
	my $map = sub { $_[0] };
	if ($text =~ /(?:^|\s)(\w+)$/) {
	    if ($1 eq lc($1)) {
		$map = sub { lc($_[0]) };
	    } elsif ($1 eq uc($1)) {
		$map = sub { uc($_[0]) };
	    }
	}
	my @list = $code->($text);
	if (! @list) {
	    $attribs->{rl_completion_suppress_append} = 1;
	    $attribs->{completion_suppress_append} = 1;
	    return '';
	}
	if (@list == 1 && ref($list[0])) {
	    # attempt filename completion
	    my ($prefix, $text) = @{$list[0]};
	    my $state = 0;
	    my @list = ('');
	    while (1) {
		my $fn = $term->filename_completion_function($text, $state);
		defined $fn or last;
		$state++;
		-d $fn && $fn !~ m|/$| and $fn .= '/';
		push @list, $prefix . $fn;
	    }
	    $attribs->{rl_completion_suppress_append} = 1;
	    $attribs->{completion_suppress_append} = 1;
	    return @list;
	}
	@list = map { $base . $map->($_) } @list;
	if (@list == 1) {
	    my ($word) = @list;
	    if ($word !~ /^\w+$|\s\w+$/) {
		$attribs->{rl_completion_suppress_append} = 1;
		$attribs->{completion_suppress_append} = 1;
	    }
	    return $word;
	}
	return '', @list;
    };
    $attribs->{rl_basic_word_break_characters} = '';
    $attribs->{basic_word_break_characters} = '';
    $attribs->{rl_basic_quote_characters} = '';
    $attribs->{basic_quote_characters} = '';
    $attribs->{rl_completer_word_break_characters} = '';
    $attribs->{completer_word_break_characters} = '';
    $attribs->{rl_special_prefixes} = '';
    $attribs->{special_prefixes} = '';
    $line;
}

END {
    eval { Term::ReadLine->deprep_terminal };
}

sub has_window { 0 }
sub is_interactive { 1 }

sub is_terminal {
    $stdwrite->is_terminal;
}

sub run {
    croak "Line mode interface should never enter run()";
}

sub start {
    croak "Line mode interface should never enter start()";
}

sub stdread {
    $stdread;
}

sub stdwrite {
    $stdwrite;
}

sub getline {
    @_ == 2 or croak "Usage: LINE->getline(PROMPT)";
    my ($line, $prompt) = @_;
    my $wobj = $line->{wobj};
    push @{$wobj->{prompt}}, $prompt;
    my $res = $line->{stdwrite}->write_text;
    pop @{$wobj->{prompt}};
    $res;
}

sub complete {
    @_ == 1 || @_ == 2 or croak "Usage: LINE->complete [(CALLBACK)]";
    my ($line, $code) = @_;
    $line->{complete} = $code;
    $line;
}

package Language::INTERCAL::Interface::Line::WOBJ;

# write() gets data from the user; this is complicated by the problem that
# the filehandle may have been stolen and if that happens it gets called
# by the server code while it's already waiting for user input, so it
# needs to know about that and be re-entrant
sub write {
    my ($wobj, $size) = @_;
    my $res = substr($wobj->{buffer}, 0, $size, '');
    return $res if length $res == $size;
    my $term = $wobj->{term};
    my $server = $wobj->{server};
    my $go = 1;
    my $nl = '';
    my $code = sub {
	($nl) = @_;
	$go = 0;
	eval { $server->file_listen_close(fileno(STDIN)); };
	$term->callback_handler_remove;
    };
    push @{$wobj->{stack}}, $code;
    $term->callback_handler_install($wobj->{prompt}[-1], $code);
    $server->file_listen(fileno(STDIN),
			 sub { $term->callback_read_char });
    while ($go) {
	$server->progress;
    }
    pop @{$wobj->{stack}};
    eval { $server->file_listen_close(fileno(STDIN)); };
    $term->callback_handler_remove;
#    my $nl = $term->readline($wobj->{prompt}, $res);
    if (defined $nl) {
	$term->addhistory($nl);
	$nl .= "\n";
	$res = substr($nl, 0, $size, '');
	$wobj->{buffer} .= $wobj->{convert}->($nl);
    } else {
	print "\n";
	$res = '';
    }
    if (@{$wobj->{stack}}) {
	# reinstate previos callback
	$code = $wobj->{stack}[-1];
	$term->callback_handler_install($wobj->{prompt}[-2], $code);
	$server->file_listen(fileno(STDIN),
			     sub { $term->callback_read_char });
    }
    return $res;
}

package Language::INTERCAL::Interface::Line::IN;

sub new {
    my ($class) = @_;
    bless \*STDIN, $class;
}

1;
