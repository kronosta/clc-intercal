package Language::INTERCAL::SymbolTable;

# Symbol table; it is separate from the parser because we have one symbol
# table per object, which can have many parsers.

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/SymbolTable.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';

sub new {
    @_ == 1 or croak "Usage: new Language::INTERCAL::SymbolTable";
    my ($class) = @_;
    bless {
	symbols => [''],
	symbolindex => {},
    }, $class;
}

sub find {
    @_ == 2 || @_ == 3
	or croak "Usage: SYMBOLTABLE->find(STRING[, SKIP_CREATION])";
    my ($table, $symbol, $skip) = @_;
    $symbol = uc $symbol;
    if (! exists $table->{symbolindex}{$symbol}) {
	return 0 if $skip;
	$table->{symbolindex}{$symbol} = @{$table->{symbols}};
	push @{$table->{symbols}}, $symbol;
    }
    $table->{symbolindex}{$symbol};
}

sub symbol {
    @_ == 2 or croak "Usage: SYMBOLTABLE->symbol(NUMBER)";
    my ($table, $symbol) = @_;
    return '' if $symbol !~ /^\d+$/ || $symbol >= @{$table->{symbols}};
    $table->{symbols}[$symbol];
}

sub max {
    @_ == 1 or croak "Usage: SYMBOLTABLE->max";
    my ($table) = @_;
    scalar @{$table->{symbols}} - 1;
}

sub grep {
    @_ == 2 or croak "Usage: SYMBOLTABLE->grep(REGEXP)";
    my ($table, $regexp) = @_;
    my @list;
    for (my $n = 1; $n < @{$table->{symbols}}; $n++) {
	$table->{symbols}[$n] =~ $regexp
	    and push @list, [$n, $table->{symbols}[$n]];
    }
    @list;
}

sub read {
    @_ == 2 or croak "Usage: SYMBOLTABLE->read(FILEHANDLE)";
    my ($table, $fh) = @_;

    my $slist = $table->{symbols};
    $fh->read_binary(pack('v', scalar @$slist));
    for (my $symbol = 1; $symbol < @$slist; $symbol++) {
	my $sym = $slist->[$symbol];
	$fh->read_binary(pack('v/a*', $sym));
    }

    $table;
}

sub write {
    @_ == 2 or croak "Usage: write Language::INTERCAL::SymbolTable(FILEHANDLE)";
    my ($class, $fh) = @_;

    my $nsymbols = unpack('v', $fh->write_binary(2)) || 0;
    my @symbols = ('');
    my %symbolindex = ();
    for (my $symbol = 1; $symbol < $nsymbols; $symbol++) {
	my $nlen = unpack('v', $fh->write_binary(2));
	my $name = $fh->write_binary($nlen);
	$symbolindex{$name} = @symbols;
	push @symbols, $name;
    }

    bless {
	symbols => \@symbols,
	symbolindex => \%symbolindex,
    }, $class;
}

1;
