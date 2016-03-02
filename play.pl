#!/usr/bin/perl

use strict;
use warnings;

use JSON;
use Data::Dumper;

#my $productsFile = "products.txt";
#my $listingsFile = "listings.txt";
my ($productsFile, $listingsFile, $outputFile) = @ARGV;
if(!defined($productsFile)) {
    die "Missing Producuts File";
}
if(!defined($listingsFile)) {
    die "Missing Listings File";
}
if(!defined($outputFile)) {
    print "No Output File, Default to output.txt\n";
    $outputFile = "output.txt";
}
my %productHash = ();
my %companyHash = ();
my %resHash = ();

open(my $fh, '<:raw', $productsFile) or die "Couldn't Open File: $!";

while(my $line = <$fh>){
    my $product = decode_json($line);
    my $manufacturer = lc($product->{'manufacturer'});
    my $family = '';
    my $model = lc($product->{'model'});;
    $model =~ s/ //g;
    if(exists($product->{'family'})) {
        $family = lc($product->{'family'});
    }
    if(!exists($productHash{$manufacturer})) {
        $productHash{$manufacturer} = ();
        my @names = split " ", $manufacturer;
        $companyHash{$manufacturer} = $manufacturer;
        foreach my $part( @names) {
            $companyHash{$part} = $manufacturer;
        }
    }
    if(!exists($productHash{$manufacturer}{$family})) {
        $productHash{$manufacturer}{$family} = ();
    }
    $productHash{$manufacturer}{$family}{$model} = $product;
}
close($fh);

open($fh, '<:raw', $listingsFile) or die "Couldn't Open File: $!";
while(my $line = <$fh>) {
    my $listing = decode_json($line);
    my $manufacturer = lc($listing->{'manufacturer'});
    if(!exists($companyHash{$manufacturer})) {
        my @parts = split(" ", $manufacturer);
        foreach my $part (@parts) {
            if(exists($companyHash{$part})) {
                $manufacturer = $companyHash{$part};
                last;
            }
        }
    }
    my $family = '';
    my $model = '';
    # Assume Listings with Battery is about the Battery and not the Camera
    # unless stated it is a kit
    if($listing->{'title'} =~ /battery/i) {
        if(!($listing->{'title'} =~ /kit/i)) {
            next;
        }
    }
    my @parts = split(" ", lc($listing->{'title'}));
    foreach my $part (@parts) {
        if(length($manufacturer) == 0) {
            if(exists($companyHash{$part})) {
                $manufacturer = $companyHash{$part};
            }
        } else {
            if(length($part) > 0 && exists($productHash{$manufacturer}{$part})) {
                $family = $part;
            } elsif(exists($productHash{$manufacturer}{$family}{$part})) {
                my $product = $productHash{$manufacturer}{$family}{$part};
                my $productName = $product->{'product_name'};
                if(!exists($resHash{$productName})) {
                    $resHash{$productName} = [];
                }
                push @{$resHash{$productName}}, $listing;
                last;
            }
        }
    }
}

close($fh);

open($fh, '>', $outputFile) or die "Couldn't Open File: $!";
my @keys = keys %resHash;
foreach my $key (@keys) {
    print $fh "{\"product_name\": \"$key\":\"listings\":".encode_json($resHash{$key})."\n";
}
