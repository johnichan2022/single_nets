#!c:\perl\bin
#####################################################################
#
#bug refdes inside refdes is showing as a net difference at pins in net check -fixed on 07Mar12
#bug reports existing pins as deleted by partial match of refded -fixed 27Mar12
#last line is ignored in netlist extraction - fixed 03Apr12
#net rename list is missed in the diff_report

## adding page no info extraction


###version .3
### adds the pin names to the refdes with modified logic to no_owner file
### filters the global nets' nodes to specific owners
### avoids writing pin names to refdes specified in the refdes_info_not_required file
### overrides refdes pin names with those specified in overriding_refdes file

## version 0.7 integreated pstxnet conversion for test

######################################################################
use File::Basename;
use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval); # For precise timing
use Time::Piece; # For time formatting

# Autoflush output for immediate timer display
$| = 1;

# Record start time
my $script_start_time = [gettimeofday];
my $last_display_time = $script_start_time->[0];

# Function to display elapsed time
sub display_elapsed_time {
    my $current_time_hires = [gettimeofday];
    my $elapsed_seconds = tv_interval($script_start_time, $current_time_hires);
    # Move cursor to the beginning of the line and overwrite
    print "\rElapsed: " . sprintf("%.0f", $elapsed_seconds) . "s";
    # Reset last display time to current for smooth updates
    $last_display_time = $current_time_hires->[0];
}


if ($#ARGV != 0 )
	 {
	 print "usage: single_net.pl plain_netlist_file.dat\n";
	exit;
	 }

# Get current time in GMT
my $gmt_start_tp = gmtime;
print "Script started at GMT: " . $gmt_start_tp->datetime . "\n"; # Display GMT start time

print "\n****** Reading Netlist ....."; display_elapsed_time();

my $inputfile1 = shift(@ARGV);

my $result   = dirname $inputfile1;


open(netlist_in, "< $inputfile1") or die "could not open the file netlist: $!\n";
my @raw_input_lines = <netlist_in>;
close netlist_in;
chomp(@raw_input_lines);
print "\n"; # Newline after reading file for cleaner timer display

open(single_nets_out, "> ".$result."/singlenets.txt") or die "could not open the file singlenets: $!\n";

print single_nets_out "0v7 Script on 03-July-2025, https://github.com/johnichan2022/single_nets\n";
print "0v7 Script on 03-July-2025, https://github.com/johnichan2022/single_nets\n";


print "****** Extracting Netlist Data..."; display_elapsed_time();
my($netlist_2d_ref) = extract_netlist_file(\@raw_input_lines);
my %netlistArray = %{$netlist_2d_ref};
print "\n"; # Newline after extraction


my $pattern1='^([\s]+)[^,]+[,][\s]$';
my $pattern2='[\s]*([^,]+)[\.][^,]+[,]';


print "****** Analyzing Nets..."; display_elapsed_time();
for(my $i=0;$i<(scalar (keys %netlistArray));$i++) {
    display_elapsed_time(); # Show progress during the main analysis loop

    my $net_name = ${$netlistArray{$i}}[0];
    my $net_pins_string = ${$netlistArray{$i}}[1];

    # Ensure $net_pins_string is defined and not empty before processing
    if (!defined $net_pins_string || $net_pins_string eq '') {
        next; # Move to the next iteration of the loop
    }

    # Explicitly cast $net_pins_string to a string here for safety
    my @pins_in_net = @{pins_in_net("" . $net_pins_string)}; # Dereference the array reference returned by pins_in_net

    if (scalar @pins_in_net == 1) {
        print single_nets_out "single net:- $net_name,".$pins_in_net[0]."\n"; # Access array element directly
    }
    elsif($net_pins_string =~ /$pattern2/) {
        my @refdes;
        my $subject = $net_pins_string;
        push @refdes, $1 while $subject =~ /([A-Z]+[0-9]*[A-Z]*[0-9]*)\.[A-Z0-9]+,/g;

        my %seen_refdes;
        foreach my $item (@refdes) {
            $seen_refdes{$item} = 1;
        }

        if (scalar(keys %seen_refdes) == 1 && scalar @pins_in_net > 1) {
            print single_nets_out "suspected single net (all pins on same refdes):- $net_name,$net_pins_string\n";
        }
    }
}
print "\n"; # Newline after analysis


print single_nets_out "Typo error check for ambiguity between digit and letters \(O,D,Q,0,o I, l,i,1,b,d,-,_\)  listed below #####\n";
print "****** Checking for Typos..."; display_elapsed_time();

my @grp1 = ("I", "l","i","1");
typo_check(\@grp1,\%netlistArray);
display_elapsed_time(); # Keep timer updating after each group

my @grp2 = ("O","D","Q","0","o");
typo_check(\@grp2,\%netlistArray);
display_elapsed_time(); # Keep timer updating

my @grp3 = ("b","d");
typo_check(\@grp3,\%netlistArray);
display_elapsed_time(); # Keep timer updating

my @grp4 = ("-","_");
typo_check(\@grp4,\%netlistArray);
print "\n"; # Newline after typo check


print single_nets_out "0v7 Script on 03-July-2025, https://github.com/johnichan2022/single_nets\n";
print "0v7 Script on 03-July-2025, https://github.com/johnichan2022/single_nets";

close single_nets_out;

# Calculate and display final elapsed time
my $final_elapsed_time = tv_interval($script_start_time);
printf "\n****** Script completed in %.3f seconds.\n", $final_elapsed_time;


# Subroutines
sub extract_netlist_file {
    my $arr1 = $_[0];
    my @netlist = @$arr1;
    my $temp1 = '';
    my $temp2 = '';
    my $temp3;
    my @temp_array_for_net;
    my $k = 0;
    my $pattern1 = 'NET_NAME';
    my $pattern2 = 'NODE_NAME[\t\s]+([A-Z]+[0-9]*[A-Z]*[0-9]+)\s+([A-Z0-9]+)$';
    my $combine_flag = 0;
    my %_netArray;

    for (my $i = 0; $i < (scalar @netlist); $i++) {
        display_elapsed_time(); # Progress inside extraction
        my $line = $netlist[$i];

        if (($line =~ m/$pattern1/) && $combine_flag == 0) {
            $temp1 = $netlist[($i + 1)];
            $combine_flag = 1;
        } elsif (($line =~ m/$pattern1/) && $combine_flag == 1) {
            $temp2 = sort_pins_in_net($temp2);
            @temp_array_for_net = ($temp1, $temp2 . ',');
            $_netArray{$k} = [@temp_array_for_net];
            $k++;
            $temp2 = '';
            $temp_array_for_net[0] = '';
            $temp1 = $netlist[($i + 1)];
            $combine_flag = 1;
        } elsif ($line =~ m/$pattern2/) {
            $temp2 .= $1 . '.' . $2 . ',';
            $temp3 = 'NODE_NAME' . "\t" . $1 . ' ' . $2;
            if ($temp3 ne $line) {
                print STDERR "Runtime Error: optimize regex for pins extraction in extract_netlist_file! Line: '$line' vs Expected: '$temp3'\n";
            }
        }
    }

    $temp2 = sort_pins_in_net($temp2);
    @temp_array_for_net = ($temp1, $temp2 . ',');
    $_netArray{$k} = [@temp_array_for_net];

    return \%_netArray;
}


sub pins_in_net {
    my $temp = $_[0];

    if (!defined $temp || $temp eq '') {
        return []; # Return an empty array reference if no pins string
    }

    my @pins_array = ($temp =~ /([A-Z]+?[0-9]*?[A-Z]*?[0-9]*?[\.][A-Z0-9]+),/gi);

    my $temp1_joined = join(',', @pins_array);
    if ($temp ne $temp1_joined . ',') {
        print STDERR "Runtime Error: optimize regex for pins isolation!!!!!!!!!!!!!!!!!!!!!!!!!\n";
        print STDERR "Original: '$temp'\n";
        print STDERR "Extracted: '$temp1_joined,'\n";
    }

    return \@pins_array;
}

sub sort_pins_in_net {
    my $temp = $_[0];

    if (!defined $temp || $temp eq '') {
        return '';
    }

    my @pins_array = ($temp =~ /([A-Z]+?[0-9]*?[A-Z]*?[0-9]*?[\.][A-Z0-9]+),/gi);
    my @sorted_pins_array = sort @pins_array;
    my $temp2_joined = join(',', @sorted_pins_array);

    my $comma_count_temp = ($temp =~ tr/,/,/);
    my $comma_count_temp2_joined = ($temp2_joined =~ tr/,/,/);

    if ($comma_count_temp != ($comma_count_temp2_joined + 1)) {
        print STDERR "Runtime Error: Mismatch in comma count between original and sorted pins in sort_pins_in_net! Original commas: $comma_count_temp, Sorted commas: $comma_count_temp2_joined. Original string: '$temp'\n";
    }

    return $temp2_joined;
}

sub typo_check {
    my $arr1 = $_[0];
    my $arr2 = $_[1];

    my @grp = @$arr1;
    my %netlistArray = %$arr2;
	print single_nets_out "Typo group check  @grp\n";
    foreach my $i (sort keys %netlistArray) {
        display_elapsed_time(); # Progress inside typo check
        my $current_net_name = ${$netlistArray{$i}}[0];
        my $len = length($current_net_name);

        for (my $j = 0; $j < (scalar @grp); $j++) {
            my $pos = index($current_net_name, $grp[$j]);

            if ($pos != -1) {
                my $temp1_part = substr($current_net_name, 0, $pos);
                my $temp2_part = substr($current_net_name, $pos + 1);

                for (my $k = 0; $k < (scalar @grp); $k++) {
                    if ($grp[$j] ne $grp[$k]) {
                        my $temp_typo_candidate = $temp1_part . $grp[$k] . $temp2_part;

                        foreach my $l (sort keys %netlistArray) {
                            if ($temp_typo_candidate eq ${$netlistArray{$l}}[0] && $l ne $i) {
                                print single_nets_out "Typo suspected at $current_net_name \t $temp_typo_candidate \n";
                            }
                        }
                    }
                }
            }
        }
    }
}