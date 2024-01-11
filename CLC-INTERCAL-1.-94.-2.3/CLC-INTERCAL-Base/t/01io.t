# Check the GenericIO code

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/01io.t 1.-94.-2

use IO::File;
use Language::INTERCAL::GenericIO '1.-94.-2';
use Language::INTERCAL::ReadNumbers '1.-94.-2', qw(roman_type read_number);
use Language::INTERCAL::WriteNumbers '1.-94.-2', qw(write_number);
use Language::INTERCAL::ArrayIO '1.-94.-2',
    qw(read_array_16 write_array_16 read_array_32 write_array_32);

print "1..72\n";
$| = 1;

my $tmpfile = ".iotest";
END { defined $tmpfile && unlink $tmpfile }

my $file;
my $string;
my $file1;
my $file2;

# 1 - FILE, text, read
$file = new Language::INTERCAL::GenericIO 'FILE', 'r', $tmpfile;
$file->read_text("TESTING\n");
$file = new IO::File $tmpfile;
print <$file> eq "TESTING\n" ? "" : "not ", "ok 1\n";

# 2 - FILE, text, write
$file = new Language::INTERCAL::GenericIO 'FILE', 'w', $tmpfile;
print $file->write_text() eq "TESTING\n" ? "" : "not ", "ok 2\n";

# 3 - FILE, binary, read
$file = new Language::INTERCAL::GenericIO 'FILE', 'r', $tmpfile;
$file->read_binary("TESTING\n");
$file = new IO::File $tmpfile;
print <$file> eq "TESTING\n" ? "" : "not ", "ok 3\n";

# 4 - FILE, binary, write
$file = new Language::INTERCAL::GenericIO 'FILE', 'w', $tmpfile;
print $file->write_binary(8) eq "TESTING\n" ? "" : "not ", "ok 4\n";

# 5 - UFILE, text, read
$file = new Language::INTERCAL::GenericIO 'UFILE', 'r', $tmpfile;
$file->read_text("TESTING\n");
$file = new IO::File $tmpfile;
print <$file> eq "TESTING\n" ? "" : "not ", "ok 5\n";

# 6 - UFILE, text, write
$file = new Language::INTERCAL::GenericIO 'UFILE', 'w', $tmpfile;
print $file->write_text() eq "TESTING\n" ? "" : "not ", "ok 6\n";

# 7 - UFILE, binary, read
$file = new Language::INTERCAL::GenericIO 'UFILE', 'r', $tmpfile;
$file->read_binary("TESTING\n");
$file = new IO::File $tmpfile;
print <$file> eq "TESTING\n" ? "" : "not ", "ok 7\n";

# 8 - UFILE, binary, write
$file = new Language::INTERCAL::GenericIO 'UFILE', 'w', $tmpfile;
print $file->write_binary(8) eq "TESTING\n" ? "" : "not ", "ok 8\n";

# 9 - ARRAY, text, read
my @data = ();
$file = new Language::INTERCAL::GenericIO 'ARRAY', 'r', \@data;
$file->read_text("TESTING\n");
print @data == 1 && $data[0] eq "TESTING\n" ? "" : "not ", "ok 9\n";

# 10 - ARRAY, text, write
$file = new Language::INTERCAL::GenericIO 'ARRAY', 'w', ["TES", "TIN", "G\n"];
print $file->write_text() eq "TESTING\n" ? "" : "not ", "ok 10\n";

# 11 - ARRAY, binary, read
@data = ();
$file = new Language::INTERCAL::GenericIO 'ARRAY', 'r', \@data;
$file->read_binary("TESTING\n");
print @data == 1 && $data[0] eq "TESTING\n" ? "" : "not ", "ok 11\n";

# 12 - ARRAY, binary, write
$file = new Language::INTERCAL::GenericIO 'ARRAY', 'w', [qw(TES TIN GXY)];
print $file->write_binary(7) eq "TESTING" &&
      $file->write_binary(99) eq "XY" ? "" : "not ", "ok 12\n";

# 13 - STRING, text, read
my $data = '';
$file = new Language::INTERCAL::GenericIO 'STRING', 'r', \$data;
$file->read_text("TESTING\n");
print $data eq "TESTING\n" ? "" : "not ", "ok 13\n";

# 14 - STRING, text, write
$string = "TESTING\nXYZT";
$file = new Language::INTERCAL::GenericIO 'STRING', 'w', \$string;
print $file->write_text() eq "TESTING\n" ? "" : "not ", "ok 14\n";

# 15 - STRING, binary, read
$data = '';
$file = new Language::INTERCAL::GenericIO 'STRING', 'r', \$data;
$file->read_binary("TESTING\n");
print $data eq "TESTING\n" ? "" : "not ", "ok 15\n";

# 16 - STRING, binary, write
$string = "TESTINGXY";
$file = new Language::INTERCAL::GenericIO 'STRING', 'w', \$string;
print $file->write_binary(7) eq "TESTING" &&
      $file->write_binary(99) eq "XY" ? "" : "not ", "ok 16\n";

# 17 - TEE, text, read
my $data1 = '';
$file1 = new Language::INTERCAL::GenericIO 'STRING', 'r', \$data1;
my $data2 = '';
$file2 = new Language::INTERCAL::GenericIO 'STRING', 'r', \$data2;
$file = new Language::INTERCAL::GenericIO 'TEE', 'r', [$file1, $file2];
$file->read_text("TESTING\n");
print $data1 eq "TESTING\n" && $data1 eq $data2 ? "" : "not ", "ok 17\n";

# 18 - TEE, binary, read
$data1 = '';
$file1 = new Language::INTERCAL::GenericIO 'STRING', 'r', \$data1;
$data2 = '';
$file2 = new Language::INTERCAL::GenericIO 'STRING', 'r', \$data2;
$file = new Language::INTERCAL::GenericIO 'TEE', 'r', [$file1, $file2];
$file->read_binary("TESTING\n");
print $data1 eq "TESTING\n" && $data1 eq $data2 ? "" : "not ", "ok 18\n";

# 19 - OBJECT, text, read
my $object = bless \$data, ReadObject;
$data = '';
$file = new Language::INTERCAL::GenericIO 'OBJECT', 'r', $object;
$file->read_text("TESTING\n");
print $data eq "TESTING\n" ? "" : "not ", "ok 19\n";

# 20 - OBJECT, text, write
$object = bless \$string, WriteObject;
$string = "TESTING\nXYZT";
$file = new Language::INTERCAL::GenericIO 'OBJECT', 'w', $object;
print $file->write_text() eq "TESTING\n" ? "" : "not ", "ok 20\n";

# 21 - OBJECT, binary, read
$object = bless \$data, ReadObject;
$data = '';
$file = new Language::INTERCAL::GenericIO 'OBJECT', 'r', $object;
$file->read_binary("TESTING\n");
print $data eq "TESTING\n" ? "" : "not ", "ok 21\n";

# 22 - OBJECT, binary, write
$object = bless \$string, WriteObject;
$string = "TESTINGXY";
$file = new Language::INTERCAL::GenericIO 'OBJECT', 'w', $object;
print $file->write_binary(7) eq "TESTING" &&
      $file->write_binary(99) eq "XY" ? "" : "not ", "ok 22\n";

# 23..36 - Read Numbers
my @list = (
    [1234,       "CLC",         'MCCXXXIV'],
    [1234,       "UNDERLINE",   'MCCXXXIV'],
    [1234,       "ARCHAIC",     '(I)CCXXXIIII'],
    [1234,       "MEDIAEVAL",   'MCCXXXIIII'],
    [1234,       "MODERN",      '_', 'ICCXXXIV'],
    [1234,       "TRADITIONAL", '', 'MCCXXXIV'],
    [1234,       "WIMPMODE",    1234],
    [5678901234, "CLC",         '\v\D\C\L\X\X\V\I\I\IcmiCCXXXIV'],
    [5678901234, "UNDERLINE",   "_v_D_C_L_X_X_V_I_I_IcmiCCXXXIV"],
    [5678901234, "ARCHAIC",     'I))))))))I)))))))((((((I))))))I))))))(((((I)))))(((((I)))))' .
				'I)))))((((I))))((((I))))((((I))))I))))(((I)))(((I)))(((I)))(((I)))(I)CCXXXIIII'],
    [5678901234, "MEDIAEVAL",   '  _    _   _  _  _  _  _ ________',
				'||L||||V|||C||L||X||X||V|MMMDCCCCMCCXXXIIII'],
    [5678901234, "MODERN",      '  _    _    _   _  _  _  _  _  _  _ ___',
				'||D||||L||||X|||D||C||C||L||X||X||X|CMICCXXXIV'],
    [5678901234, "TRADITIONAL", '_         ___', 'vdclxxviiiCMICCXXXIV'],
    [5678901234, "WIMPMODE",    5678901234],
);
@data = ();
my $testnum = 23;
$file = new Language::INTERCAL::GenericIO 'ARRAY', 'r', \@data;
for my $n (@list) {
    my ($num, $type, @result) = @$n;
    @data = ();
    read_number($num, roman_type($type), $file);
    my $ok = @data == @result;
    if ($ok) {
	chomp @data;
	for (my $i = 0; $i < @data; $i++) {
	    $ok = 0 if $data[$i] ne $result[$i];
	}
    }
    print $ok ? '' : 'not ', 'ok ', $testnum++, "\n";
}

# 37..60 Write numbers
@list = (
    ['ONE OH ZERO TWO THREE FOUR FIVE', 1002345],
    ['SIX SEVEN NINER EIGHT NINE', 67989],
    ['AON A H-AON AONAR DA DHA TRIUIR A NAOI', 1112239],
    ['A DHA NONI NEONI DITHIS TRI CEITHIR NAONAR', 2002349],
    ['A TRI A CEITHIR CEATHRAR COIG A COIG SIA', 344556],
    ['CÒIG C\`OIG A C\`OIG A CÒIG COIGNEAR C\`OIGNEAR', 555555],
    ['CÒIGNEAR SE A SIA A SE SEANAR SEACHD', 566667],
    ['A SEACHD SEACHDNAR OCHD A H-OCHD OCHDNAR NAOI', 778889],
    ['EKA DVI TRI SUTYA CHATUR PANCHAN', 123045],
    ['SHASH SHUTYA SAPTAM ASHTAN NAVAN', 60789],
    ['BAT BI HIRO LAU ZEROA BORTZ', 123405],
    ['SEI ZAZPI ZORTZI BEDERATZI', 6789],
    ['ISA DALAWA TATLO APAT WALA LIMA', 123405],
    ['ANIM PITO WALO SIYAM', 6789],
    ['CE OME IEI NAUI NACUILI AHTLE', 123450],
    ['CHIQUACE CHICOME CHICUE CHICUNAUI', 6789],
    ['ERTI ORI SAMI OTXI NULI XUTI', 123405],
    ['EKSVI SHVIDI RVA CXRA', 6789],
    ["'NEM MAL'H YUDEXW MU SEK'A Q'ETL'A", 123456],
    ["ETLEBU KE'YOS MALHGWENALH 'NA'NE'MA", 7089],
    ['BAL TEL KIL FOL LUL M\\"AL MÄL', 1234566],
    ['VEL J\\"OL NOS JÖL Z\\"UL ZÜL', 780899],
    ["UNUS UNA UNUM DUO NIL DUAE DUÆ DU\\AE TRES", 111202223],
    ["QUATTUOR QUINQUE SEX NIHIL SEPTEM OCTO NOVEM", 4560789],
);
$testnum = 37;
my $win = join("\n", map { $_->[0] } @list);
$file = new Language::INTERCAL::GenericIO 'STRING', 'w', \$win;
for my $n (@list) {
    my ($out, $in) = @$n;
    my $n = write_number($file, 0);
    print defined $n && $n == $in ? '' : 'not ', 'ok ', $testnum++, "\n";
}

# 61..66 - read array
@list = (
    [\&read_array_16, 'CLC', 0, undef, 'Hello, World',
     91, 95, 84, 95, 65, 83, 83, 88, 91, 76, 68, 95, 82, 95, 88, 74, 83, 73],
    [\&read_array_32, 'CLC', 0, undef, 'Pleasure to meet you',
     3422748677, 1823736845, 558760182, 1223229687, 3168141630, 575406774,
     4222943924, 2596733168, 124190837, 1023152199, 2074214626, 2064122373,
     1203114246, 2930967199, 660930815, 52363501, 2511863925, 375328790,
     2930639514, 515967526],
    [\&read_array_16, 'C', 69, 38, 'Hello, World',
     51, 108, 112, 0, 64, 194, 48, 26, 244, 168, 24, 16],
    [\&read_array_32, 'C', 0, 38, 'Hello, World',
     238, 108, 112, 0, 64, 194, 48, 26, 244, 168, 24, 16],
);
my $rou = '';
$file = new Language::INTERCAL::GenericIO 'STRING', 'r', \$rou;
$testnum = 61;
for my $n (@list) {
    my ($code, $iotype, $iovalue, $lastvalue, $result, @array) = @$n;
    $rou = '';
    $file->reset;
    $code->($iotype, \$iovalue, $file, \@array, 0);
    my $ok = $rou eq $result;
    print $ok ? '' : 'not ', 'ok ', $testnum++, "\n";
    defined $lastvalue or next;
    $ok = $lastvalue == $iovalue;
    print $ok ? '' : 'not ', 'ok ', $testnum++, "\n";
}

# 67..72 - write array
@list = (
    [\&write_array_16, 'CLC', 0, undef, undef, 'Hello, World',
     91, 95, 84, 95, 65, 83, 83, 88, 91, 76, 68, 95, 82, 95, 88, 74, 83, 73],
    [\&write_array_32, 'CLC', 0, undef, 0xffff, 'Pleasure to meet you',
     5, 1037, 246, 247, 318, 694, 692, 240, 117, 4167, 226, 517, 4358,
     671, 255, 237, 117, 4118, 666, 2598],
    [\&write_array_16, 'C', 69, 100, undef, 'Hello, World',
     3, 29, 7, 0, 3, 189, 244, 55, 24, 3, 250, 248],
    [\&write_array_32, 'C', 0, 100, undef, 'Hello, World',
     72, 29, 7, 0, 3, 189, 244, 55, 24, 3, 250, 248],
);
$win = '';
$file = new Language::INTERCAL::GenericIO 'STRING', 'w', \$win;
$testnum = 67;
for my $n (@list) {
    my ($code, $iotype, $iovalue, $lastvalue, $mask, $text, @result) = @$n;
    $win = $text;
    $file->seek(0);
    my @win = $code->($iotype, \$iovalue, $file, length $text);
    my $ok = @win == @result;
    if ($ok) {
	for (my $i = 0; $i < @win; $i++) {
	    my $x = $win[$i];
	    $x &= $mask if defined $mask;
	    $ok = 0 if $result[$i] != $x;
	}
    }
    print $ok ? '' : 'not ', 'ok ', $testnum++, "\n";
    defined $lastvalue or next;
    $ok = $lastvalue == $iovalue;
    print $ok ? '' : 'not ', 'ok ', $testnum++, "\n";
}

package ReadObject;

sub read {
    my ($obj, $data) = @_;
    $$obj .= $data;
}

package WriteObject;

sub write {
    my ($obj, $size) = @_;
    substr($$obj, 0, $size, '');
}

