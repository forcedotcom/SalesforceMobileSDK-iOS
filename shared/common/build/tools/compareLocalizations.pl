#!/usr/bin/perl
#
# See the documentation at the bottom of this script, or run it with the --help option
#

use XML::LibXML;
use Getopt::Long;
use Pod::Usage;

my $opt_reference;
my $opt_verbose;
my $opt_fix;
my $opt_ask;
my $opt_help;
GetOptions(
    "reference=s" => \$opt_reference,
    "verbose"     => \$opt_verbose,
    "fix"         => \$opt_fix,
    "ask"         => \$opt_ask,
    "help!"       => \$opt_help,
) or pod2usage("Try '$0 --help' for more information.");

pod2usage( -verbose => 2 ) if $opt_help;

pod2usage(-msg => "No files to compare against were supplied")
    unless @ARGV;

my $parser = XML::LibXML->new();

my $refDoc = $parser->parse_file($opt_reference)
    or die "Can't parse XML file $reference\n";

my %changes = ();
foreach my $compareFile (@ARGV) {
    next if $compareFile eq $opt_reference;
    compare(\%changes, $refDoc, $compareFile);
}

print "DIFFERENCES:\n";
foreach my $section (keys %changes) {
    foreach my $param (keys %{ $changes{$section} }) {
        my @diffFiles = @{ $changes{$section}{$param} };
        if (@diffFiles) {
            my $text = $refDoc->findvalue("//section[\@name='$section']/param[\@name='$param']");
            print "$section/$param: $text\n\t", join("\n\t", @diffFiles), "\n";
        }
    }
}

sub compare {
    my ($changes, $original, $compareFile) = @_;
    my $compareDoc = $parser->parse_file($compareFile);

    my $origRoot = $original->documentElement;
    my $compareRoot = $compareDoc->documentElement;
    my $numchanges = 0;

    # Loop through the different sections in the reference document
    foreach my $origSection (@{ $origRoot->findnodes('//section') }) {
        #$compare->{$sectionName} ||= {};
        my $sectionName = $origSection->getAttribute('name');
        my ($compareSection) = $compareRoot->findnodes("//section[\@name='$sectionName']");
        unless ($compareSection) {
            warn "Can't find section named $sectionName in the reference file $compareFile\n"
                if $opt_verbose;
            next;
        }

        # Loop through each param within this section
        foreach my $origParam (@{ $origSection->findnodes('param') }) {
            #$compare->{$sectionName}{$paramName} ||= [];

            my $paramName = $origParam->getAttribute('name');
            my ($compareParam) = $compareSection->findnodes("param[\@name='$paramName']");

            unless ($compareParam) {
                warn "Can't find a parameter named $paramName in the reference file $compareFile, section named '$sectionName'\n"
                    if $opt_verbose;
                next;
            }

            my $origValue = $origParam->textContent();
            my $compareValue = $compareParam->textContent();
            if ($origValue eq $compareValue) {
                warn "Parameter name '$paramName' is identical between the reference document and $compareFile\n"
                    if $opt_verbose;
                push @{ $changes->{$sectionName}{$paramName} }, $compareFile;

                # Attempt to fix the changes by removing duplicates in other language files
                if ($opt_fix) {
                    if ($opt_ask) {
                        print "Eliminate duplicate? $compareFile: $paramName ($origValue) [Y]/N: ";
                        my $answer = <STDIN>;
                        if (lc($answer) =~ /^n/) {
                            next;
                        }
                    }

                    # Find all the following-siblings until the next node, so we can remove them too
                    my @deleteNodes = ($compareParam);

                    my $nextSibling = $compareParam->nextSibling;
                    while ($nextSibling && $nextSibling->nodeType != XML_ELEMENT_NODE) {
                        push @deleteNodes, $nextSibling;
                        $nextSibling = $nextSibling->nextSibling;
                    }

                    $compareSection->removeChild($_) for @deleteNodes;
                    $numchanges++;
                }
            }
        }
    }

    if ($opt_fix and $numchanges > 0) {
        warn "Writing $numchanges changes to $compareFile\n";
        $compareDoc->toFile($compareFile);
    }
}

__END__

=head1 NAME

compareLocalizations.pl - Identify and optionally fix duplicate strings in localized files

=head1 SYNOPSIS

    compareLocalizations.pl --reference LocalizationEN.xml Localization*.xml

=head1 DESCRIPTION

This tool compares multiple SFDC localization XML files to a reference file (typically in English),
and identifies any localizations that are identical, optionally fixing the duplicates as it goes.

In some circumstances plain-English strings make it into localizations, copied verbatim from the
original English text.  When this happens, those strings are not visible to the localization team
as text that needs to be translated.

This script targets those erroneous duplicates and removes them from the localized files, allowing
the localization team to see and address them.

=head1 USAGE 

=over 4

=item C<r> | C<reference> (required)

The filename that will be used as the reference localization (almost always this should
be the English version of the file).

=item C<f> | C<fix>

Tells compareLocalizations.pl to attempt to fix the duplicates, by removing them (and the
associated comments) from the file.

=item C<a> | C<ask>

When used in combination with C<--fix> this option, this will ask you whether or not
you want to make a given change automatically.

=item C<v> | C<verbose>

Makes this script chattier about what it's doing.

=item C<h> | C<help>

This help text.

=back

=cut

