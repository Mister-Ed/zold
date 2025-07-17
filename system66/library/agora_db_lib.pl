$versions{'agora_db_lib.pl'} = '06.6.00.0000';
$sc_db_engine = 'flatfile';

# Written by Steve Kneizys for AgoraCart
# 20 user version by Mister Ed for AgoraCart
#
# Some of this comes from the original WEB_STORE_DB_LIB.PL
# (written by Gunther Birznieks  -- "Feel free to copy,
#  cite, reference, sample, borrow, resell or plagiarize the
#  contents..." :)
#
# Purpose: This library contains the routines that the
# store uses to interface with a flatfile (plain
# ASCII text file) database file.
#
# Special Note: If you wish to interface with a SQL database
# such as mSQL, this is where you do it. Simply replace the
# routines in here with routines that call the database
# engine of your choice.
#
# Some of the Main Procedures:
#
#  add_new_record_to_prod_db - self explanatory
#
#  check_db_with_product_id - The web store takes
#    this procedure and double checks that the order
#    within the cart matches the product description
#    in the database.  This is a security check.
#
#  del_prod_from_db - self explanatory
#
#  get_next_prod_key - Get the next key, padded correctly
#    for sorting purposes
#
#  get_prod_db_category_list - get list of categories
#
#  get_prod_db_element -  Get the numbered element
#    from EVERY product database record
#
#  get_prod_db_row - get row from product database
#
#  put_prod_db_raw_line - replace a record in the product database
#
#  submit_query - This routine submits a query to
#    the product database and returns the results in an array
#    for each row returned (returns the record keys).
#
# Generic routines for all databases when implementing for agora.  The
# routines above can (should?) call these routines to get the job done,
# especially if you desire to have add-on modules function properly.
#
#  get_db_row - get row from a database
#
#  put_db_raw_line - replace/add record to a database
#
#  init_a_database - init a database, set indexing, etc.
#
#  pad_key - Pad a key to a certain length, allows
#    easier sorting
#
#  get_db_element -  Get the numbered element from EVERY record
#
#  submit_a_query - This routine submits a query to
#    a database and returns the results in an array
#    for each row returned (returns the record keys).
#
# Note: this library assumes zeroth element of a record is record key, and
# that record's field delimiter is pipe ('key|field 1|field 2|...').
#
##############################################################################
#
# The hash %db_file_defs must have something defined for each
# database a database implementation has defined, such as:
#   $db_file_defs{'PRODUCT'} = '1';
# You can use the variable for anything, in this library it
# holds the full path to the file, but it must be defined!
#
##############################################################################

sub get_prod_db_category_list {
    local ( %db_ele, %category_list );
    $sc_categorylist_only = '1';
    get_prod_db_element( $db{'product'}, *db_ele );
    foreach $sku ( keys %db_ele ) {
        $category = $db_ele{$sku};
        $category_list{$category} = 1;
    }
    $sc_categorylist_only = q{};
    return ( sort( keys %category_list ) );
}

############################################################
#
# subroutine: check_db_with_product_id
#   Usage:
#     $status = &check_db_with_product_id($product_id,
#                  *db_row);
#
#   Parameters:
#     $product_id = product id in the cart to check
#     *db_row = @db_row passed by reference to
#        obtain the row that corresponds to the
#        product id.
#
#   Output:
#     $status = whether the product id is has been
#        found in the database. If it has not, then
#        we know right away that something went wrong.
#
#     @db_row is returned by reference to the calling
#        sub routine. It contains the row in the DB that
#        matches the product ID. This row can then be
#        checked by the Web Store to see if other items such
#        as price match the cart item.  Each element of
#        @db_row is a field in the database.
#
############################################################

sub check_db_with_product_id {
    local ( $product_id, *db_row ) = @_;
    local ( $result, $db_raw_line, $result );
    $result = &get_prod_db_row( $product_id, *db_row, *db_raw_line, "yes" );
    return $result;

}

############################################################
#
# get a row from product database
#
############################################################

sub get_prod_db_row {
    local ( $product_id, *db_row, *db_raw_line, $cacheok ) = @_;
    local ( $db_product_id, $save_the_line, $filename );
    $db_product_id = q{};

    #
    # First we open the data file.
    # If the open fails. We call the
    # file open error routine in order
    # to log the error
    #

    if ( !( $sc_db_flatfile_caching_ok =~ /yes/i ) ) { $cacheok = 'no'; }
    $db_raw_line = q{};    #init it
                          # if read before and caching, don't read again!
    if ( ( $cacheok =~ /yes/i ) && ( $db_cache{$product_id} ne '' ) ) {
        $line  = $db_cache{$product_id};
        @db_row   = split( /\|/, $line );
        $db_raw_line = $line;
        return 1;
    }

    $filename = $db_file_defs{'PRODUCT'};

    open( DATAFILE, "$filename" )
      || file_open_error( "$filename", "$agora_read_db_error_title", __FILE__,__LINE__ );

    #
    # Each line in the data file
    # is read into $line variable.
    #
    # Then, it is split into
    # fields which are placed in
    # @db_rows.
    #
    # If it turns out that the
    # product id matches the
    # product id in the database
    # row, the while loop will
    # stop, and the db_row will
    # contain the row matching
    # the product id.
    #
    while ( ( $line = <DATAFILE> ) && ( $product_id ne $db_product_id ) ) {
        chop($line);
        @db_row        = split( /\|/, $line );
        $save_the_line = $line;
        $db_product_id = $db_row[0];
        if ( $cacheok =~ /yes/i ) {
            $db_cache{$db_product_id} = $save_the_line;
        }
    }

    #
    # Save result, in case we need it later
    if ( $product_id eq $db_product_id ) {
        $db_raw_line = $save_the_line;
    }

    close(DATAFILE);

    # return the result of the boolean expression
    return ( $product_id eq $db_product_id );

}    # End of sub get_prod_db_row
############################################################################
sub get_db_row {
    local ( $dbname, $product_id, *db_row, *db_raw_line, $cacheok ) = @_;
    local ( $db_product_id, $save_the_line, $filename );
    $db_product_id = q{};

    #
    # First we open the data file.
    # If the open fails. We call the
    # file open error routine in order
    # to log the error
    #

    $db_raw_line = q{};    #init it

    $filename = $db_file_defs{$dbname};

    open( DATAFILE, "$filename" )
      || file_open_error( "$filename", "$agora_read_db_error_title", __FILE__,
        __LINE__ );

    #
    # Each line in the data file
    # is read into $line variable.
    #
    # Then, it is split into
    # fields which are placed in
    # @db_rows.
    #
    # If it turns out that the
    # product id matches the
    # product id in the database
    # row, the while loop will
    # stop, and the db_row will
    # contain the row matching
    # the product id.
    #
    while (( $line = <DATAFILE> )
        && ( $product_id ne $db_product_id ) )
    {
        chop($line);
        @db_row        = split( /\|/, $line );
        $save_the_line = $line;
        $db_product_id = $db_row[0];
    }

    #
    # Save result, in case we need it later
    if ( $product_id eq $db_product_id ) {
        $db_raw_line = $save_the_line;
    }

    close(DATAFILE);

    # return the result of the boolean expression

    return ( $product_id eq $db_product_id );

}    # End of sub get_db_row
#################################################################
# sub get_prod_db_element(<element>,<*assoc array>);
#
# Get the numbered element from EVERY PRODUCT database record!
#
#################################################################
sub get_prod_db_element {
    local ( $element_id, *db_ele ) = @_;
    get_db_element( 'PRODUCT', 0, $element_id, 'last', *db_ele );
}
#################################################################
sub get_mgr_prod_db_element {
    local ( $element_id, *db_ele ) = @_;
    get_db_element( 'PRODUCT', 0, $element_id, 'mgr', *db_ele );
}
#################################################################
sub get_prod_db_keys {
    local ( $element_id, %db_ele );
    $element_id = 0;    #redundant, but works
    get_db_element( 'PRODUCT', 0, $element_id, 'last', *db_ele );
    return ( keys %db_ele );
}
#################################################################
sub get_db_keys {
    local ($dbname) = @_;
    local ( $element_id, %db_ele );
    $element_id = 0;    #redundant, but works
    get_db_element( $dbname, 0, $element_id, 'last', *db_ele );
    return ( keys %db_ele );
}    # End of sub get_db_keys
#################################################################
# sub get_db_element(<datafile>,
#                             <ID element>,
#                             <element to retrieve>,
#                             <what to do with duplicates>,
#                             <*assoc array>);
#
# Get the numbered element from EVERY flatfile database record!
#
#   <what to do with duplicates> = "last" or "all"
#
#################################################################
sub get_db_element {
    local ( $data_file, $id_inx, $element_id, $dups, *db_ele ) = @_;
    local ( $db_id, $db_subcat, $db_subkey, $save_the_line, @db_row, $db_raw_line );
    local $data_file_path = $db_file_defs{"$data_file"};

    my ($thiscat, $newcat) = q{};
    my ($supercats) = qq{$sc_add_on_modules_dir/supercats.pl};
    my @cat_listing;

    open( DATAFILE, $data_file_path )
      || file_open_error( $data_file_path, " $agora_read_db_error_title ",__FILE__, __LINE__ );

# conditional routing added for subcategory processing.
    if (   ( $sc_use_database_subcats =~ /yes/i )
        && ( $dups =~ /last/i )
        && ( $sc_categorylist_only ne '1' ) )
    {

        while ( ( $line = <DATAFILE> ) ) {
            @db_row    = split( /\|/, $line );
            $db_id     = $db_row[$id_inx];
            $db_subcat = $db_row[ $db{$sc_subcat_index_field} ];
            $db_subkey = $db_row[$element_id];

            #main category
            if ( $sc_count_database_cats =~ /yes/i ) {
                $db_ele2{$db_subkey}++;
            }
            if ( $db_ele{$db_subkey} eq '' ) {
                $db_ele{$db_subkey} = $db_row[$element_id];
            }

###########################################################################################
#	SuperCats Version-6.x
# Added by DigitalArtifact 05/29/2010
# updated for Gold version 6.x by Mister Ed - June 2012
# Needed for counting products in each category
# added support for the SuperCat multi subcat module
###########################################################################################
	if ( -e $supercats ) {
		# Here we set this main cat as
		# a main cat in our cat list
		specify_cats($db_subkey, '', '', 1);

		if ($sc_count_database_cats =~ /yes/i) {
			contents_counter($db_subkey);
		}

		# To prevent the counter from counting multiple instances of a cat name
		# that may occur in the user field of a single product we will enter its
		# name in a new hash for each product then check it for every iteration
		# of our subcat user field loop
		my (%anti_sub_dup) = ();

		if ( $db_subcat ) {
			my @db_subcatarray = split(/::/, $db_subcat);

			foreach $db_subcatarray (@db_subcatarray) {

				if ( $sc_use_database_subcats =~ /yes/i ) {
					# use regex to check for ISNEWCAT or ISROOTED or ISKEYCAT
					# if true then split them out and process their lists
					# expect format from database to be as follows:
					# ISNEWCAT= new_cat_name = root_it_here, ISKEYCAT <-- can fall any where in the comma seperated list
					# ISNEWCAT= new_cat_name = root_it_here, ISKEYCAT, root_it_here <-- As such
					if ( ( $db_subcatarray =~ m/ISNEWCAT=/ ) || ( $db_subcatarray =~ m/ISNEWCAT =/ ) ){

						# split to remove the word "ISNEWCAT" and to seperate the
						# newcat from its rooted list. If the rooted list does
						# not exist or contains null then this new cat is rooted
						# as a main cat of tree.
						@cat_listing = ( split( /=/, $db_subcatarray ) );
						$newcat = $cat_listing[1];
						specify_cats($newcat, "", "", 0);

						if ( ( $sc_count_database_cats =~ /yes/i ) && ( $newcat ne $db_subkey ) && ( ! exists($anti_sub_dup{$newcat} ) ) ) {
							contents_counter($newcat);
							$anti_sub_dup{$newcat} = q{};
						}

						# Then we split again to get the list of cats to
						# assign the main split off the list of rooted cats
						# then cycle through them adding them to their
						# perspective places in catlist
						@cat_listing = ( split( /,/, $cat_listing[2] ) );

						for $thiscat( @cat_listing ){
							if ( $thiscat =~ m/ISKEYCAT/ ){
								# Forces a specific cat to be the main cat that all
								# other cats branch off of. No matter what index it
								# is located at, in the tree, it imediately takes
								# posission as the main cat in the menu.
								specify_cats($newcat, "KEYCAT", "", 0);
							}
							elsif ( $thiscat =~ m/ISSTATICCAT/ ){
								# This is because we are going to use the mapper hash in the manager
								# to create our link information for a static html page because there
								# is no product in the database for it. This enables us to have a link
								# to a static page apear in our menu hiearchy
								specify_cats($newcat, "STATIC", "", 0);
							}
							elsif ( $thiscat =~ m/ISMAINCAT/ ){
								# This will force a category that is created in a product
								# userfield to appear in the menu tree as a main category.
								# should ONLY be used with "ISSTATICCAT"
								specify_cats($newcat, "", "", 1);
							}
							else {
								specify_cats($newcat, "ROOTED", $thiscat, 0);
								specify_cats($thiscat, "SUBCAT",$newcat , 0);

								if ( ($sc_count_database_cats =~ /yes/i) && ($thiscat ne $db_subkey) && (! exists($anti_sub_dup{$thiscat})) ){
									contents_counter($thiscat);
									$anti_sub_dup{$thiscat} = q{};
								}
							}
						}
					}
					elsif ( ( $db_subcatarray =~ m/ISROOTED=/ ) || ( $db_subcatarray =~ m/ISROOTED =/ ) ){
						# This prevents the main cat from being at root
						# of tree by rooting under another cat.
						# split to remove the ISROOTED then split again
						# to get the list of cats to assign the main cat
						# to be a subcat of. Expect from database as follows:
						# ISROOTED= root_it_here, root_it_here, root_it_here
						@cat_listing = ( split( /=/, $db_subcatarray ) );
						@cat_listing = ( split( /,/, $cat_listing[1] ) );

						for $thiscat( @cat_listing ){
							if ( $thiscat =~ m/EXCLUSIVE/ ) {
								specify_cats($db_subkey, "EXCLUSIVE", "", 0);
							}
							else {
								specify_cats($db_subkey, "ROOTED", $thiscat, 0);
								specify_cats($thiscat, "SUBCAT", $db_subkey, 0);

								if ( ($sc_count_database_cats =~ /yes/i) && ($thiscat ne $db_subkey) && (! exists($anti_sub_dup{$thiscat})) ) {
									contents_counter($thiscat);
									$anti_sub_dup{$thiscat} = q{};
								}
							}
						}
					}
					elsif ( ( $db_subcatarray =~ m/ISKEYCAT=/ ) || ( $db_subcatarray =~ m/ISKEYCAT =/ ) ){
						# split to remove the word "ISKEYCAT"
						@cat_listing = ( split( /=/, $db_subcatarray ) );

						# Then we split again to get the list of cats to
						# assign as KEYCATS then cycle through them adding
						# them to their perspective places in catlist
						@cat_listing = ( split( /,/, $cat_listing[1] ) );

						for $thiscat( @cat_listing ){
							# Forces a specific cat to be the main cat that all
							# other cats branch off of. No matter what index it
							# is located at, in the tree, it imediately takes
							# posission as the main cat in the menu.
							specify_cats($thiscat, "KEYCAT", "", 0);
						}
					}
					elsif ( $db_subcatarray =~ m/ISKEYCAT/ ){
						# This sets the main cat as a keycat only
						# Must be in the normal cat place in the user field
						# so lets make the main cat a keycat
						specify_cats($db_subkey, "KEYCAT", "", 0);
					}
					elsif ( ( $sc_count_database_cats =~ /yes/i ) && ( $db_subcatarray ne $db_subkey ) && (! exists($anti_sub_dup{$db_subcatarray})) ) {
						# Then we must be counting how many items are
						# in our categories to show our shoppers
						contents_counter($db_subcatarray);
						$anti_sub_dup{$db_subcatarray} = q{};
					}
				}
			}
		}
	}
################## end of big super cats edit #######
            # sub categories
            elsif ( $db_subcat =~ /::/ ) {
                my @db_subcatarray = split( /::/, $db_subcat );
                foreach my $db_subcatarray (@db_subcatarray) {
                    $db_ele{$db_subkey}->{$db_subcatarray}++;
                }
            }
            elsif ( $db_subcat ) {
                $db_ele{$db_subkey}->{$db_subcat}++;
            }
        }
        if ( -e $supercats ) {
            grow_cat_tree();
            save_cat_house();
        }
    }
    else {

        #existing code
        while ( ( $line = <DATAFILE> ) ) {
            @db_row    = split( /\|/, $line );
            $db_id     = $db_row[$id_inx];
            $db_subcat = $db_row[10];            # sub categories
            if ( ( $db_ele{$db_id} ) && ( $dups =~ /all/i ) ) {
                $db_ele{$db_id} .= '|' . $db_row[$element_id];
            }
            else {
                $db_ele{$db_id} = $db_row[$element_id];
            }
        }
    }
    close(DATAFILE);

    return;
}    # End of sub get_flatfile_db_element
############################################################
# sub get_next_prod_key
#
# Get the next key, padded correctly for sorting purposes
# This routine does NOT "reserve" this next key, two people
# editing simultaneously will get the same next key ...
# should not be a problem for most folks, this was how the
# original code worked as well.
############################################################
sub get_next_prod_key {
    local ( $element_id, %db_ele, $highest, $next_key, $mykey );
    local ($padlength) = $sc_prod_db_pad_length;

    # Doesn't matter what we ask for, we just want all the keys
    $element_id = $db{'product'};
    get_mgr_prod_db_element( $element_id, *db_ele );
    $highest = 0;
    foreach $mykey (%db_ele) {
        if ( $mykey > $highest ) {
            $highest = $mykey;
        }
    }
    $next_key = pad_key( ( $highest + 1 ), $padlength );
    return $next_key;
}
############################################################
# Pad a key to a certain length, allows easier sorting!
############################################################
sub pad_key {
    local ( $next_key, $padlength ) = @_;
    while ( length($next_key) < $padlength ) {
        $next_key = "0$next_key";
    }
    return $next_key;
}
############################################################
sub put_prod_db_raw_line {
    local ( $product_id, $db_raw_line,   $cacheok )        = @_;
    local ( $result, $db_product_id, $ProductEditSku ) = 0;
    local (
        $sku,    $category,    $price,
        $short_description,   $image,    $long_description,
        $shipping_price,      $userDefinedOne,      $userDefinedTwo,
        $userDefinedThree,    $userDefinedFour,     $userDefinedFive,
        $userDefinedSix,      $userDefinedSeven,    $userDefinedEight,
        $userDefinedNine,     $userDefinedTen,      $userDefinedEleven,
        $userDefinedTwelve,   $userDefinedThirteen, $userDefinedFourteen,
        $userDefinedFifteen,  $userDefinedSixteen,  $userDefinedSeventeen,
        $userDefinedEighteen, $userDefinedNineteen, $userDefinedTwenty,
        $SpecialsPrice,  $NetProfits, $WholesalePrice, $Inventory,
        $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options, $junk,
        $line,  @lines
    );

    #
    # First we open the data file.
    # If the open fails. We call the
    # file open error routine in order
    # to log the error
    #
    #Note: could check to see if $product_id and $ProductEditSku match!
    ( $ProductEditSku, $junk ) = split( /\|/, $db_raw_line, 2 );

    $filename = $db_file_defs{'PRODUCT'};
    &get_file_lock("${filename}.lock");
    open( OLDFILE, "$filename" ) || my_die("Can't Open $filename");
    @lines = <OLDFILE>;

    #print @lines;
    close(OLDFILE);
    open( NEWFILE, ">$filename" ) || my_die("Can't Open $filename");

    foreach $line (@lines) {

        if ( $sc_userfields_available eq '10' ) {
            (
                $sku,        $category,
                $price,         $short_description,
                $image,         $long_description,
                $shipping_price,      $userDefinedOne,
                $userDefinedTwo,      $userDefinedThree,
                $userDefinedFour,     $userDefinedFive,
                $userDefinedSix,      $userDefinedSeven,
                $userDefinedEight,    $userDefinedNine, $userDefinedTen,
                $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
                $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options
            ) = split( /\|/, $line );
        }
        elsif ( $sc_userfields_available eq '20' ) {
            (
                $sku,        $category,
                $price,         $short_description,
                $image,         $long_description,
                $shipping_price,      $userDefinedOne,
                $userDefinedTwo,      $userDefinedThree,
                $userDefinedFour,     $userDefinedFive,
                $userDefinedSix,      $userDefinedSeven,
                $userDefinedEight,    $userDefinedNine,
                $userDefinedTen,      $userDefinedEleven,
                $userDefinedTwelve,   $userDefinedThirteen,
                $userDefinedFourteen, $userDefinedFifteen,
                $userDefinedSixteen,  $userDefinedSeventeen,
                $userDefinedEighteen, $userDefinedNineteen, $userDefinedTwenty,
                $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
                $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options
            ) = split( /\|/, $line );
        }
        else {
            (
                $sku,     $category,
                $price,      $short_description,
                $image,      $long_description,
                $shipping_price,      $userDefinedOne,
                $userDefinedTwo,      $userDefinedThree,
                $userDefinedFour,     $userDefinedFive,
                $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
                $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options
            ) = split( /\|/, $line );
        }

        if ( $sku eq $product_id ) {
            print NEWFILE $db_raw_line . "\n";
            $result = 1;
        }
        else {
            print NEWFILE $line;
        }
    }

    close(NEWFILE);
    &release_file_lock("${filename}.lock");

    if ( $result ne 1 ) {
        $result = &add_new_record_to_prod_db($db_raw_line);
    }

    if ( $db_cache{$ProductEditSku} ne '' ) {
        $db_cache{$ProductEditSku} = q{};
    }

    # if written ok and caching, don't need to read again!
    if ( ( $cacheok =~ /yes/i ) && ($result) ) {
        $db_cache{$ProductEditSku} = $db_raw_line;
    }
    return $result;

}    # End of put_prod_db_raw_line
############################################################
sub put_db_raw_line {
    local ( $dbname, $product_id, $db_raw_line, $cacheok ) = @_;
    local ( $result, $db_product_id, $ProductEditSku ) = 0;
    local (
        $sku,      $category,     $price,
        $short_description,   $image,        $long_description,
        $shipping_price,      $userDefinedOne,      $userDefinedTwo,
        $userDefinedThree,    $userDefinedFour,     $userDefinedFive,
        $userDefinedSix,      $userDefinedSeven,    $userDefinedEight,
        $userDefinedNine,     $userDefinedTen,      $userDefinedEleven,
        $userDefinedTwelve,   $userDefinedThirteen, $userDefinedFourteen,
        $userDefinedFifteen,  $userDefinedSixteen,  $userDefinedSeventeen,
        $userDefinedEighteen, $userDefinedNineteen, $userDefinedTwenty,
        $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
        $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options, $junk,
        $line, @lines
    );

    #
    # First we open the data file.
    # If the open fails. We call the
    # file open error routine in order
    # to log the error
    #
    # if $db_raw_line is null, then delete any such line
    # from the database and do not add if not present.
    #
    #Note: could check to see if $product_id and $ProductEditSku match!
    ( $ProductEditSku, $junk ) = split( /\|/, $db_raw_line, 2 );

    $filename = $db_file_defs{$dbname};
    get_file_lock("${filename}.lock");
    open( OLDFILE, "$filename" ) || my_die("Can't Open $filename");
    @lines = <OLDFILE>;

    #print @lines;
    close(OLDFILE);
    open( NEWFILE, ">$filename" ) || my_die("Can't Open $filename");

    foreach $line (@lines) {
        ( $sku, $junk ) = split( /\|/, $line, 2 );

        if ( $sku eq $product_id ) {
            if ( $db_raw_line ) { print NEWFILE $db_raw_line . "\n"; }
            $result = 1;
        }
        else {
            print NEWFILE $line;
        }
    }

    if ( $result ne 1 ) {
        if ( $db_raw_line ne '' ) { print NEWFILE $db_raw_line . "\n"; }
        $result = 1;
    }

    close(NEWFILE);
    release_file_lock("${filename}.lock");

    return $result;

}    # End of put_db_raw_line
############################################################
sub del_prod_from_db {
    local ($product_id) = @_;
    local ( $db_raw_line, $cacheok ) = @_;
    local ( $result, $db_product_id, $ProductEditSku ) = 0;
    local (
        $sku,         $category,     $price,
        $short_description,   $image,       $long_description,
        $shipping_price,      $userDefinedOne,      $userDefinedTwo,
        $userDefinedThree,    $userDefinedFour,     $userDefinedFive,
        $userDefinedSix,      $userDefinedSeven,    $userDefinedEight,
        $userDefinedNine,     $userDefinedTen,      $userDefinedEleven,
        $userDefinedTwelve,   $userDefinedThirteen, $userDefinedFourteen,
        $userDefinedFifteen,  $userDefinedSixteen,  $userDefinedSeventeen,
        $userDefinedEighteen, $userDefinedNineteen, $userDefinedTwenty,
        $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
        $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options, $junk,
        $line, @lines
    );

    #
    # First we open the data file.
    # If the open fails. We call the
    # file open error routine in order
    # to log the error
    #
    #Note: could check to see if $product_id and $ProductEditSku match!
    ( $ProductEditSku, $junk ) = split( /\|/, $db_raw_line, 2 );

    $filename = $db_file_defs{'PRODUCT'};
    get_file_lock("${filename}.lock");
    open( OLDFILE, "$filename" ) || my_die("Can't Open $filename");
    @lines = <OLDFILE>;

    #print @lines;
    $result = 0;
    close(OLDFILE);
    open( NEWFILE, ">$filename" ) || &my_die("Can't Open $filename");

    foreach $line (@lines) {
        if ( $sc_userfields_available eq '10' ) {
            (
                $sku,        $category,
                $price,         $short_description,
                $image,         $long_description,
                $shipping_price,      $userDefinedOne,
                $userDefinedTwo,      $userDefinedThree,
                $userDefinedFour,     $userDefinedFive,
                $userDefinedSix,      $userDefinedSeven,
                $userDefinedEight,    $userDefinedNine,
                $userDefinedTen,
                $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
                $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options
            ) = split( /\|/, $line );
        }
        elsif ( $sc_userfields_available eq '20' ) {
            (
                $sku,        $category,
                $price,         $short_description,
                $image,         $long_description,
                $shipping_price,      $userDefinedOne,
                $userDefinedTwo,      $userDefinedThree,
                $userDefinedFour,     $userDefinedFive,
                $userDefinedSix,      $userDefinedSeven,
                $userDefinedEight,    $userDefinedNine,
                $userDefinedTen,      $userDefinedEleven,
                $userDefinedTwelve,   $userDefinedThirteen,
                $userDefinedFourteen, $userDefinedFifteen,
                $userDefinedSixteen,  $userDefinedSeventeen,
                $userDefinedEighteen, $userDefinedNineteen,
                $userDefinedTwenty,
                $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
                $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options
            ) = split( /\|/, $line );
        }
        else {
            (
                $sku,     $category,
                $price,      $short_description,
                $image,      $long_description,
                $shipping_price,      $userDefinedOne,
                $userDefinedTwo,      $userDefinedThree,
                $userDefinedFour,     $userDefinedFive,
                $SpecialsPrice, $NetProfits, $WholesalePrice, $Inventory,
                $IsTaxable, $TaxTypeID, $SpecialTaxRateAdjust, $ShipRateAdjust, $options
            ) = split( /\|/, $line );
        }

        if ( $sku eq $product_id ) {
            $result = 1;
        }
        else {
            print NEWFILE $line;
        }
    }

    close(NEWFILE);
    release_file_lock("${filename}.lock");

#################### delete shipping file ##################
    my ( $sku, $indicator, $length, $width, $height, $girth, $boxtype,
        $alt_origin_postalcode, $alt_origin_stateprov );

    get_file_lock("${shipfilename}.lock");
    open( OLDSHIPFILE, "$shipfilename" ) || my_die("Can't Open $shipfilename");
    @lines = <OLDSHIPFILE>;

    #print @lines;
    $result = 0;
    close(OLDSHIPFILE);
    open( NEWSHIPFILE, ">$shipfilename" )
      || my_die("Can't Open $shipfilename");

    foreach $line (@lines) {
        (
            $sku, $boxindicator, $length, $width, $height, $girth, $boxtype,
            $alt_origin_postalcode, $alt_origin_stateprov
        ) = split( /\|/, $line );
        if ( $sku ne $product_id ) {
            print NEWSHIPFILE $line;
        }
    }
    close(NEWSHIPFILE);
    release_file_lock("${shipfilename}.lock");
#################### end delete shipping file ##################

    if ( $db_cache{$ProductEditSku} ) {
        $db_cache{$ProductEditSku} = q{};
    }

    return $result;

}    # End of del_prod_from_db
#######################################################################
sub add_new_record_to_prod_db {

    local ($my_new_rec) = @_;
    local ($filename);

    $filename = $db_file_defs{'PRODUCT'};
    get_file_lock("${filename}.lock");
    open( NEW, "+>> $filename" ) || &my_die("Can't Open $filename");
    print( NEW "$my_new_rec\n" );
    close(NEW);
    release_file_lock("${filename}.lock");

    return 1;

}
############################################################
#
# subroutine: submit_query
#   Usage:
#     ($status, $row_count) = submit_query(*db_rows);
#
#   Parameters:
#     *db_rows = an empty array is passed by reference
#       so that it can be filled with the contents of
#       the rows that satisfy the query.
#
#   Output:
#     $status = blank is no error. It contains an
#       abbreviated name of the error that occured if
#       there was a problem with the query such as
#       "max_rows_exceeded".
#
#     $row_count = amount of rows that satisfied query
#       even if the count exceeded the maximum allowed.
#       This row count will never actually exceed
#       1 above the row count in the flat file version
#       of this routine because it is inefficient to
#       keep reading a text file if we do not
#       intend to present the user with the subsequent
#       information.
#
#     *db_rows = an array where each row is a row that
#       satisfied the results of the query. The rows
#       stop being added to this array if $sc_max_rows
#       setup variable is exceeded.
#
#       Each row contains the fields in a PIPE delimited
#       form.
#
############################################################
sub submit_query {
    local (*database_rows) = @_;
    local ( $status, $rowcount );
    ( $status, $row_count ) =
      submit_a_query( 'PRODUCT', $sc_db_max_rows_returned, *form_data,
        *sc_db_query_criteria, *database_rows );
    if ( ( $row_count == 0 ) && ( $main_program_running =~ /yes/i ) ) {
        PrintNoHitsBodyHTML();
        call_exit();
    }
    return ( $status, $row_count );
}
############################################################
# Submitted/Modified 10-11-2003 by Jeffrey W. Hamilton
# Additional edits by Mister Ed - K-Factor Technologies, Inc.
# - Cleaned up code for speed and clarity
# Returns:
#	Value 1: "max_rows_exceeded" if more products than the
#              maximum rows requested is returned in the list
#     Value 2: A list of product_id for each matching product
#              in sorted order
############################################################
sub submit_a_query {
    local ( $dbname, $sc_db_max_rows_returned, *form_data,
        *sc_db_query_criteria, *database_rows )
      = @_;
    local (@fields);
    local ($status, $row_count, $line);

    # We initialize row count to 0.
    #
    $row_count = 0;

    #
    # The first thing we need to do is
    # open the data file and then check to
    # see if there was an error doing this.
    #

    $filename = $db_file_defs{$dbname};
    local @patch_short_criteria = patch_short_criteria();

    open( DATAFILE, "$filename" )
      || file_open_error( "$filename", 'Read Database', __FILE__, __LINE__ );

    #
    # If there was no error opening it,
    # then we read each line into $line
    # until the file ends or the row count
    # exceeds the maximum rows returned plus
    # 1.
    #

    while ( $line = <DATAFILE> ) {
        chop($line);    # Chop off extraneous newline

        # Each field is split based on the pipe
        # delimiter.
        @fields = split( /\|/, $line );

        # Then, for each criteria
        # specified in @sc_db_query_criteria,
        # we call a routine to apply the
        # criteria.

        foreach $criteria (@patch_short_criteria) {
            if ( ( $criteria =~ /$sc_subcat_index_field/ ) && ( $sc_use_database_subcats =~ /yes/i ) ) {
                #$form_data{$sc_subcat_index_field} = query_by_URL_cleaner($form_data{$sc_subcat_index_field});
            }
            $not_found = flatfile_apply_criteria( *fields, $criteria );
            last if ($not_found);
        }

        # If not found conditional true then
        # the row count has not exceeded
        # the amount of rows that we
        # promised to return,
        # the row is pushed into the
        # @db_rows array.
        #
        if ( !$not_found ) {

            # put in conditional to not return inactive items
            # added by Mister Ed August 15, 2006
            if ( $fields[$sc_inactive_user_number] !~ /inactive/i ) {

                # Line in database matches all criteria
                push( @database_rows, $fields[0] );
                $row_count++;
            }
        }
    }    # End of while datafile has data

    # Finally, we close the datafile when
    # we are done with it.

    close(DATAFILE);

    # We passed database rows by reference so that
    # no extra copying of the array is needed when
    # we return the status.
    #
    if ( $row_count > $sc_db_max_rows_returned ) {
        $status = 'max_rows_exceeded';
    }

    # added by Mister Ed December 20, 2008
    #   originally done by MAS - aka Mark S. in 2004
    # altered by Mister Ed for inclusion in core code.
    #$sc_sort_your_way = "yes";
    if ( $sc_sort_your_way =~ /yes/i ) {
        my ( $item, $dum, @how );
        local (%new_rows);
        my @sort_key;
        my ( $field_ref, $fieldval, $sort_key, $item );
        my (@sort_how_ref) = ();

        # test data for "how to search"
        # A = Ascending, D = Descending
        # common DB fields are:
        # price name description shipping user1 user2 user3 user4 user5
        # $sc_custom_sort_how = ['name|A'];
        # $sc_custom_sort_how = ['price|A%5.2f'];
        foreach (@$sc_custom_sort_how) {
            @how = /(.*?)\|(.)(.*)/;
            $how[0] = $db{ $how[0] };

            push @sort_how_ref, [@how];
        }

        # Get each line from the database that matches
        foreach $item (@database_rows) {

            # These results have already been checked
            $dum = check_db_with_product_id( $item, *row );
            @sort_key = ();

            # Retrieve each field. Evaluate it per sorting mask
            foreach $field_ref (@sort_how_ref) {

                #mask each field

                $fieldval = $row[ $field_ref->[0] ];

                $fieldval = sprintf( $field_ref->[2], $fieldval )
                  if $field_ref->[2];

                if ( $field_ref->[1] eq 'D' ) {
                    @fieldval = map chr( 256 - ord($_) ),
                      ( split '', $fieldval );
                    $fieldval = join '', @fieldval;
                }

                push @sort_key, $fieldval;
            }    # Apply each SET of field masks to each row

            # We have to put something in the sort key to make sure that
            # it is always distinct
            push @sort_key, $row[ $db{product_id} ];
            $sort_key = join "|", @sort_key;

            $new_rows{$sort_key} = $item;
        }    # sort what loop

        @database_rows = map $new_rows{$_}, ( sort keys %new_rows );

        # end of custom sorting routines
    }
    else {

        # Sort them so they are in product id number order
        @database_rows = sort(@database_rows);
    }

    # Finally, we return the status and
    # the row count.
    #
    return ( $status, $row_count );
}    # End of submit_a_query
############################################################
#
# subroutine: flatfile_apply_criteria
#  Usage:
#      $status = &flatfile_apply_criteria(
#	$exact_match,
#	$case_sensitive,
#	*fields,
#	$criteria);
#
#   Parameters:
#      $exact_match = on if the user
#        selected to perform exact whole word matches
#        on the database strings
#      $case_sensitive = on if the user
#        selected to perform case sensitive matches
#        on the database strings.
#      *fields is a reference to the array of fields
#       in the current database row that we are
#       searching.
#      $criteria is the current criteria that we
#       are applying to the database row. The criteria
#       is gathered from the @sc_query_criteria array
#       from the setup file.
#
#   Output:
#     status indicating whether the criteria was
#     not found or not. If it is not found, a 1
#     is returned. If it is, then a 0 is returned.
#
# Submitted/Modified 10/11/2003 by Jeffrey W. Hamilton
# Additional edits by Mister Ed - K-Factor Technologies, Inc.
# - Cleaned up code for speed and clarity
# - Fixed date compares to handle a wider range of dates
# - Added exactly equal matches for strings
# Returns: 0 if the data row matches the given criteria
#          1 if the data row does not match the given criteria
############################################################
sub flatfile_apply_criteria {
    local ( *fields, $criteria ) = @_;

    # format for the $criteria line
    # the criteria is pipe delimited and
    # consists of the form variable name
    # that the criteria will be matched
    # against, the fields in the database
    # which will be matched against,
    # the operator to use in comparison,
    # and finally, the data type that the
    # operator should use in the comparison
    # (date, number, or string comparison).
    #
    local ( $c_name, $c_fields, $c_op, $c_type );

    # array of c_fields
    local (@criteria_fields);

    # flag for whether we found something
    local ($not_found);

    # Value for form field
    local ($form_value);

    # Value for db field
    local ($db_value);

    # Date Comparison Place holders
    local ( $month, $year, $day );
    local ( $db_date, $form_date );

    # Place marker for current database
    # field index we are looking at
    local ($db_index);

    # list of words in a string for matching
    local (@word_list);

    #
    # exact_match and case_sensitive
    # are special form variables
    # which alter the behavior of
    # keyword searches (string data
    # type with the = operator).
    #
    # Normally keyword searches are
    # case insensitive and are not
    # exact match searches.
    #
    local ($exact_match)    = $form_data{'exact_match'};
    local ($case_sensitive) = $form_data{'case_sensitive'};

    # Get criteria information
    ( $c_name, $c_fields, $c_op, $c_type ) =
      split( /\|/, $criteria );

    # The criteria can match more than ONE
    # field in the database! Thus, we get the
    # index values of the fields in each row
    # of the database that the form variable
    # will be compared against.
    #
    # Remember, fields and lists in perl
    # start counting at 0.
    #
    @criteria_fields = split( /,/, $c_fields );

    # We get the value of the form.
    #
    $form_value = $form_data{$c_name};

    # agora DELUXE ... if multiple instances of the variable were on the
    # form, then readparse uses the \0 as the delimiter.  We desire them
    # to be a single instance delimited by spaces, so we just substitute

    if ( ( $c_name =~ /$sc_subcat_index_field/ ) && ( $sc_use_database_subcats =~ /yes/i ) ) {
        $form_value =~ s/-grthan-/ \> /;
        $form_value = query_by_URL_cleaner($form_value);
        #print $form_value . ' --> ' . $form_data{$sc_subcat_title_name} . '<br>';
    }
    #$form_value =~ s/\0/ /g;
    $form_value =~ s/(\s+)/ /g;
    $form_value =~ s/(^\s)//g;

    # There are three cases of comparison
    # that will return a value.
    #
    # Case 1: The form field for the criteria
    # was not filled out, so the match is
    # considered a success.
    #
    # Remember, if the user does not
    # enter a keyword, we want the search
    # to be open-ended. Only restrict the
    # search if the user chooses to enter
    # a search word into the appropriate
    # query field.

    if ( $form_value eq '' ) {

        # if no data is stored in form, assume it matches
        return 0;
    }

    # Case 2: The data type is a
    # number or a date. OR if
    # the data type is a string
    # and the operator is NOT
    # =. So we match against the
    # operator directly based on the
    # data type. (A string,= match
    # is considered a separate case
    # below).
    #

    if (   ( $c_type =~ /date/i )
        || ( $c_type =~ /number/i )
        || ( $c_op ne '=' ) )
    {

        # First, we set not_found to yes.
        # We assume that the data did not
        # match. If any fields match
        # the data submitted by the user,
        # then, we will set not_found to no
        # later on.
        $not_found = 'yes';

        # Go through each database field
        # specified in @criteria_fields
        # and compare it
        foreach $db_index (@criteria_fields) {

            # Go through each database field
            # specified in @criteria_fields
            # and compare it
            $db_value = $fields[$db_index];

            # Date field comparison
            if ( $c_type =~ /date/i ) {

                # Clean up date in database field
                ( $month, $day, $year ) = split( /\//, $db_value );
                $month = '0' . $month if ( length($month) < 2 );
                $day   = '0' . $day   if ( length($day) < 2 );

                # Years between 0 and 50 are assumed to be in the
                # 2000's. Years between 51 and 99 are assumed to
                # be in the 1900's.
                if ( $year > 50 && $year < 100 ) {
                    $year += 1900;
                }
                if ( $year <= 50 ) {
                    $year += 2000;
                }
                $db_date = $year . $month . $day;

                # Clean up date given in HTML form
                ( $month, $day, $year ) = split( /\//, $form_value );
                $month = '0' . $month if ( length($month) < 2 );
                $day   = '0' . $day   if ( length($day) < 2 );
                if ( $year > 50 && $year < 100 ) {
                    $year += 1900;
                }
                if ( $year <= 50 ) {
                    $year += 2000;
                }
                $form_date = $year . $month . $day;

                # If any of the date comparisons match
                # then a 0 is returned to let the submit_query
                # routine know that a match was found.
                if ( $c_op eq '>' ) {
                    return 0 if ( $form_date > $db_date );
                }
                if ( $c_op eq '<' ) {
                    return 0 if ( $form_date < $db_date );
                }
                if ( $c_op eq '>=' ) {
                    return 0 if ( $form_date >= $db_date );
                }
                if ( $c_op eq '<=' ) {
                    return 0 if ( $form_date <= $db_date );
                }
                if ( $c_op eq '!=' ) {
                    return 0 if ( $form_date != $db_date );
                }
                if ( ( $c_op eq '=' ) || ( $c_op eq '==' ) ) {
                    return 0 if ( $form_date == $db_date );
                }

                #
                # If the data type is a number
                # then we perform normal number
                # comparisons in Perl.
            }
            elsif ( $c_type =~ /number/i ) {
                if ( $c_op eq '>' ) {
                    return 0 if ( $form_value > $db_value );
                }
                if ( $c_op eq '<' ) {
                    return 0 if ( $form_value < $db_value );
                }
                if ( $c_op eq '>=' ) {
                    return 0 if ( $form_value >= $db_value );
                }
                if ( $c_op eq '<=' ) {
                    return 0 if ( $form_value <= $db_value );
                }
                if ( $c_op eq '!=' ) {
                    return 0 if ( $form_value != $db_value );
                }
                if ( ( $c_op eq '=' ) || ( $c_op eq '==' ) ) {
                    return 0 if ( $form_value == $db_value );
                }

                # String comparisons that are not equal done on
                # whole fields.
                # If the data type is a string
                # then we take the operators and
                # apply the corresponding Perl string
                # operation. For example, != is ne,
                # > is gt, etc.
                #
            }
            else {
                if ( $c_op eq '>' ) {    # $c_type is a string
                    return 0 if ( $form_value gt $db_value );
                }
                if ( $c_op eq '<' ) {
                    return 0 if ( $form_value lt $db_value );
                }
                if ( $c_op eq '>=' ) {
                    return 0 if ( $form_value ge $db_value );
                }
                if ( $c_op eq '<=' ) {
                    return 0 if ( $form_value le $db_value );
                }
                if ( $c_op eq '!=' ) {
                    return 0 if ( $form_value ne $db_value );
                }
                if ( $c_op eq '==' ) {
                    return 0 if ( $form_value eq $db_value );
                }
            }
        }    # End of foreach $form_field

    }
    else {    # End of case 2, Begin Case 3
              # Case 3: The data type is a string and
              #         the operator is =. This is
              #         more complex because we need
              #         to check whether our string
              #         matching matches whole words
              #         or is case sensitive.
              #
              #         In otherwords, this is a more
              #         "fuzzy" search.
              #
              # arguments: $exact_match, $case_sensitive
              #            affect the search
              # In addition, the form_value will be split
              # on whitespace so that white-space separated
              # words will be searched separately.
              #
              # Take the words that were entered and parse them into
              # an array of words based on word boundary (\s+ splits on
              # whitespace)

        if ( $sc_search_box_toggle =~ /SeparateWords/ ) {
            # words are separated by whitespace
            @word_list = split(/\s+/,$form_value);
        }
        else {
            # search box is an exact string. This is default for speed improvement
            @word_list = split( /\0/, $form_value );
        }

        # Again, we go through the fields in the
        # database that are checked for this
        # particular criteria
        # definition.

        foreach $db_index (@criteria_fields) {

            # Obtain the value of the database field
            # we are currently matching against.

            $db_value  = $fields[$db_index];
            $not_found = 'yes';

            # $match_word is a place marker for the words
            # we are going to be looking for in the database row
            # $x is a place marker inside the for loops.

            local ($match_word) = q{};
            local ($x)          = q{};

            ####### START OF KEYWORD SEARCH #####
            #
            # This routine is the same as the HTML
            # Search Engine find_keywords subroutine
            #
            # Basically, the deal is that as the
            # words get found, they get removed
            # from the @word_list array.
            #
            # When the array is empty, we know
            # that all the keywords were found.
            #
            # We will later celebrate this
            # event by returning the fact that
            # a match was found for this criteria.
            #
            if ( $case_sensitive eq 'on' ) {
                if ( $exact_match eq 'on' ) {
                    for ( $x = @word_list ; $x > 0 ; $x-- ) {

                        # \b matches on word boundary
                        $match_word = $word_list[ $x - 1 ];
                        if ( $db_value =~ /\b$match_word\b/ ) {
                            splice( @word_list, $x - 1, 1 );
                        }    # End of If
                    }    # End of For Loop
                }
                else {
                    for ( $x = @word_list ; $x > 0 ; $x-- ) {
                        $match_word = $word_list[ $x - 1 ];
                        if ( $db_value =~ /$match_word/ ) {
                            splice( @word_list, $x - 1, 1 );
                        }    # End of If
                    }    # End of For Loop
                }    # End of ELSE
            }
            else {
                if ( $exact_match eq 'on' ) {
                    for ( $x = @word_list ; $x > 0 ; $x-- ) {

                        # \b matches on word boundary
                        $match_word = $word_list[ $x - 1 ];
                        if ( $db_value =~ /\b$match_word\b/i ) {
                            splice( @word_list, $x - 1, 1 );
                        }    # End of If
                    }    # End of For Loop
                }
                else {
                    for ( $x = @word_list ; $x > 0 ; $x-- ) {
                        $match_word = $word_list[ $x - 1 ];
                        if ( $db_value =~ /$match_word/i ) {
                            splice( @word_list, $x - 1, 1 );
                        }    # End of If
                    }    # End of For Loop
                }    # End of ELSE
            }
            ####### END OF KEYWORD SEARCH #######

        }    # End of foreach $db_index

        # If there is nothing left in the word_list
        # we want to say that we found the word
        # in the $db_value. Thus, $not_found is set to
        # "no" in this case.

        if ( @word_list < 1 ) {
            $not_found = 'no';
        }

    }    # End of case 3

    # If not_found is still equal to yes,
    # we return a 1, indicating that the
    # criteria was not satisfied
    #
    # If not_found is not yes, then
    # we return that a successful match
    # was found (0).
    #
    if ( $not_found eq 'yes' ) {
        return 1;
    }
    else {
        return 0;
    }
}    # End of flatfile_apply_criteria

#######################################################################
# Some other routines that are not used for flatfile database but
# may be useful or required to implement for other databases
#######################################################################
sub init_agora_database_library {
    #define the product file and its location
    $db_file_defs{'PRODUCT'} = "$sc_data_file_path";
}
#######################################################################
sub open_product_database {
    # is a no-op, database is opened on demand in flatfile routines
}
#######################################################################
sub init_product_database {
    # used in manager routines for CSV
    $filename = $db_file_defs{'PRODUCT'};
    open( NEWFILE, ">$filename" ) || my_die("Can't Open $filename");
    close(NEWFILE);
}
#######################################################################
sub open_a_database {
    local ( $name, $path ) = @_;

    # database is opened on demand in flatfile routines
    # but we need to set the db_file_defs for it!
    if ( $path eq '' ) { $path = "$sc_data_file_dir"; }
    $db_file_defs{"$name"} = "$path/$name";
    return;
}
#######################################################################
sub init_a_database {

    # required for real database implementations
    local (
        $name,
        $path,
        $fields_to_index_by_keyword,    # optional
        $fields_to_index_as_is,         # optional
        @fieldnames                     # optional ?
    ) = @_;

    # In a real db implementation, if just the name (and perhaps path) are
    # given and the database exists, keep the current definition and only
    # erase all records currently in the database (leave indexing alone.)
    codehook( 'init_a_database_top' );
    if ( $db_file_defs{"$name"} ) {

        # already 'opened', so we know where to init the file
        $zpath = $db_file_defs{"$name"};
    }
    else {
        if ( $path eq '' ) { $path = "$sc_data_file_dir"; }
        $zpath = "$path/$name";
    }
    $zpath =~ /([^\xFF]*)/;
    $zpath = $1;

    #print "Content-type: text/html;\n\n$zpath<br>\n";
    open( NEWFILE, ">$zpath" ) || my_die("Can't Open $zpath");
    close(NEWFILE);
    return;
}
#######################################################################
sub close_all_databases {

    # is a no-op, databases opened/closed on demand in flatfile routines
}
#######################################################################
sub match_pattern_in_database {
    # is a no-op, not currently used, but should be in here!  Especially
    # needed for customer database lookups by phone number or email addr
    # returns list of keys in the @array pointed to by *keylist
    local ( $db_name, $db_field, $pattern, $case_sens_bool, *keylist ) = @_;
    return;
}
#######################################################################
# Free Contribution by Mark S. (MAS aka Algernon), an AgoraCart Pro member.
#
# DISCUSSION: The default Agora database engine will check for every
# search test to every single record in your database, even if none of
# those tests apply to what you are currently attempting to do. The
# typical criteria list has 10 search types in it, so if you're clicking
# on 'Category' in your database of 10,000 entries the flat file
# criteria routine will be called 100,000 times when it only should be
# called 10,000 times.
#
#######################################################################
sub patch_short_criteria {
    local @patch_db_query_criteria;
    local ( $criteria, $c_name, $c_fields, $c_op, $c_type, $form_value );
    foreach $criteria (@sc_db_query_criteria) {
        ( $c_name, $c_fields, $c_op, $c_type ) = split( /\|/, $criteria );

        @criteria_fields = split( /,/, $c_fields );
        $form_value = $form_data{$c_name};
        $form_value =~ s/\0/ /g;
        $form_value =~ s/(\s+)/ /g;
        $form_value =~ s/(^\s)//g;

        next if ( $form_value eq '' );
        push @patch_db_query_criteria, $criteria;
    }

    return @patch_db_query_criteria;

}
############################################################
#
# get a row from the product shipping dimensions database.
#
############################################################
sub get_prod_shipping_dimensions_in_db_row {
    my ($product_id) = @_;
    my ( $db_product_id, $save_the_line, $result );
    my (@ds_db_row);
    $db_product_id = q{};

    #
    # First we open the data file.
    # If the open fails. We call the
    # file open error routine in order
    # to log the error
    #

    open( DATAFILE, "$shipfilename" ) || file_open_error( "$shipfilename",
        "$agora_read_db_error_title", __FILE__, __LINE__ );

    while ( ( $line = <DATAFILE> ) && ( $product_id ne $db_product_id ) ) {
        chomp($line);
        @ds_db_row     = split( /\|/, $line );
        $save_the_line = $line;
        $db_product_id = $ds_db_row[0];
    }

    if ( $product_id eq $db_product_id ) {
        $result =
"$ds_db_row[6],$ds_db_row[1],$ds_db_row[2],$ds_db_row[3],$ds_db_row[4],$ds_db_row[5],$ds_db_row[7],$ds_db_row[8]";
    }
    close(DATAFILE);

    return $result;

}
############################################################
sub check_db_with_product_id_for_info {
    local ( $product_id, $data_field_thingy, *db_row ) = @_;
    local ( $result, $db_raw_line );
    $result =
      get_prod_thingy_in_db_row( $product_id, $data_field_thingy, *db_row,
        *db_raw_line, 'yes' );
    return $result;
}
############################################################
#
# get a row from product database version 2.  Added for alt db data
#
############################################################

sub get_prod_thingy_in_db_row {
    local ( $product_id, $data_field_thingy, *db_row, *db_raw_line, $cacheok ) =
      @_;
    local ( $db_product_id, $save_the_line, $filename, $result );
    $db_product_id = q{};

    #
    # First we open the data file.
    # If the open fails. We call the
    # file open error routine in order
    # to log the error
    #

    if ( !( $sc_db_flatfile_caching_ok =~ /yes/i ) ) { $cacheok = 'no'; }
    $db_raw_line = q{};    #init it
                          # if read before and caching, don't read again!
    if ( ( $cacheok =~ /yes/i ) && ( $db_cache{$product_id} ) ) {
        $line = $db_cache{$product_id};
        @db_row = split( /\|/, $line );

        $result      = $db_row[$data_field_thingy];
        $db_raw_line = $line;
        return $result;
    }

    $filename = $db_file_defs{'PRODUCT'};

    open( DATAFILE, "$filename" )
      || file_open_error( "$filename", "$agora_read_db_error_title", __FILE__,
        __LINE__ );

    #
    # Each line in the data file
    # is read into $line variable.
    #
    # Then, it is split into
    # fields which are placed in
    # @db_rows.
    #
    # If it turns out that the
    # product id matches the
    # product id in the database
    # row, the while loop will
    # stop, and the db_row will
    # contain the row matching
    # the product id.
    #
    while ( ( $line = <DATAFILE> )
        && ( $product_id ne $db_product_id ) )
    {
        chop($line);
        @db_row        = split( /\|/, $line );
        $save_the_line = $line;
        $db_product_id = $db_row[0];
        if ( $cacheok =~ /yes/i ) {
            $db_cache{$db_product_id} = $save_the_line;
        }
    }

    # Save result, in case we need it later
    if ( $product_id eq $db_product_id ) {
        $db_raw_line = $save_the_line;
        $result      = "$db_row[$data_field_thingy]";
    }

    close(DATAFILE);

    return $result;
}
#######################################################################
#
# $sc_db_lib_was_loaded is set to "yes"
# to make sure that the db library
# is not loaded more than once within
# the store script. The main
# store script checks to see
# if this variable is set before it
# attempts to require this library.
#

if ( $sc_db_lib_was_loaded ne 'yes' ) {
    $sc_db_lib_was_loaded = 'yes';
    init_agora_database_library();
    open_product_database();
    add_codehook( 'cleanup_before_exit', 'close_all_databases' );
}
#############################################################################
1;
