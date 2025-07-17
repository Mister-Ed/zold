$versions{'cart.pl'} = '06.6.00.0002';

#######################################################################
#
# AgoraCart and all associated files, except where noted, are
# Copyright 2001 to Present jointly by K-Factor Technologies, Inc.
# and by C E Mayo (aka Mister Ed) at AgoraCart.com & K-Factor.net
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This copyright notice may not be removed or altered in any way.
#
#######################################################################

#
#
# Contains the subroutines/functions for adding, deleting and
# modifying items in a shopping cart.
#
#

#######################################################################
#                    Add to Shopping Cart
#######################################################################
#
# The add_to_the_cart subroutine is used to add items to
# the customer's unique cart.  It is called with no
# arguments with the following syntax:
#
# add_to_the_cart();
#
#######################################################################

sub add_to_the_cart {
    local ( @database_rows, @database_fields, @item_ids, @display_fields );
    local ( $qty, $line, $line_no, $cart_row_qty, $cart_row_middle ) = q{};
    local ( $junk, $zzzitem, $temp, $web_id_number ) = q{};
    local ( %item_opt_verify, @lines, @testme );
    local ( $need_bad_order_note, $wildcard_id_number ) = q{};
    local ($order_count) = 0;
    local ($failed) = q{};
    checkReferrer();    # now only tests for repeats as of 4.0L

    if ( $sc_db_lib_was_loaded ne 'yes' ) {
        require_supporting_libraries( __FILE__, __LINE__, "$sc_db_lib_path" );
    }


    # Option for donation sites mostly, so that when a new item is added, the old
    # one cart contents is emptied, so that only one item remains.
    if ( $template_empty_cart_for_single_donation_line eq 'yes' ) {
        empty_cart();
    }

    # the script first opens the user's shopping cart with read/write access,
    # creating it if for some reason it is not already there. If there is a
    # problem opening the file, it will call file_open_error subroutine
    # to handle the error reporting.

    open( CART, "+>>$sc_cart_path" ) || file_open_error(
        "$sc_cart_path", "$agora_error_logging_notice02", __FILE__, __LINE__
    );

    # The script then retrieves the highest item number of the items already
    # in the cart (if any). The item number is an arbitrary number used to
    # uniquely identify each item, as described below.

    # init highest item number (start at 100)
    $highest_item_number = 100;

    # make sure we're positioned at top of file
    seek( CART, 0, 0 );

    # loop on cart contents, if any
    while (<CART>)

    {

        # get rid of terminating newline
        chomp $_;

        # split cart row into fields
        my @row = split( /\|/, $_ );

        # get item number of row (last field)
        my $item_number_info = pop(@row);
        ( $item_number, $item_modifier ) = split( /\*/, $item_number_info, 2 );

        $highest_item_number = $item_number
          if ( $item_number > $highest_item_number );

    }

    # $highest_item_number is now either the highest item number,
    # or 0 if the cart was empty.  Close the file.

    close(CART);

    #before anything must reset any special variable options, if present
    update_special_variable_options('reset');

    # The script must first figure out what the client has
    # ordered.
    #
    # It begins by using the %form_data associative array
    # given to it by cgi-lib.pl.  It takes all of the keys
    # of the form_data associative array and drops them into
    # the @items_ordered array.
    #
    # Note: An associative array key is like a variable name
    # whereas an associative array value is the
    # value associated with that variable name. The
    # benefit of an associative array is that you can have
    # many of these key/value pairs in one array.
    # Conveniently enough, you'll notice that input fields on
    # HTML forms will have associated NAMES and VALUES
    # corresponding to associative array KEYS and VALUES.
    #
    # Since each of the text boxes in which the client could
    # enter quantities were associated with the database id
    # number of the item that they accompany, (as defined
    # in the display_page routine at the end of this
    # script), the HTML should read
    #
    #         <INPUT TYPE = "text" NAME = "1234">
    #
    # for the item with database id number 1234 and
    #
    #         <INPUT TYPE = "text" NAME = "5678">
    #
    # for item 5678.
    #
    # If the client orders 2 of 1234 and 9 of 5678, then
    # @incoming_data will be a list of 1234 and 5678 such that
    # 1234 is associated with 2 in %form_data associative
    # array and 5678 is associated with 9.  The script uses
    # the keys function to pull out just the keys.  Thus,
    # @items_ordered would be a list like (1234, 5678, ...).

    foreach my $key ( sort (keys(%form_data)) ) {
        if ( ( $sc_donation_mode eq 'yes' ) && ( $key =~ /^option\|donationAmount/ ) && ( $sc_use_verified_opt_values eq 'no' ) ) {
            $form_data{$key} =~ /(\d+)/;
            $form_data{$key} = $1;
            if ( ( $form_data{$key} > 0 ) && ( $form_data{$key} !~ /notused/i ) && ( $form_data{$key} !~ /\-1/ ) ) {
                push (@items_ordered, $key);
            }
        }
        elsif ( $key ne '' ) {
            push (@items_ordered, $key);
        }
    }
    #@items_ordered = sort( keys(%form_data) );

    # Next it begins going through the list of items ordered
    # one by one.

    foreach my $item (@items_ordered) {

        # However, there are some incoming items that don't need
        # to be processed. Specifically, we do not care about cart_id,
        # page, keywords, add_to_cart, or whatever incoming
        # administrative variables exist because these are all
        # values set internally by this script. They will be
        # coming in as form data just like the client-defined
        # data, and we will need them for other things, just not
        # to fill up the user's cart. In order to bypass all of
        # these administrartive variables, we use a standard
        # method for denoting incoming items.  All incoming items
        # are prefixed with the tag "item-".  When the script sees
        # this tag, it knows that it is seeing an item to be added
        # to the cart.
        #
        # Similarly, items which are actually options info are
        # denoted with the "option" keyword.  We will also accept
        # those for further processing.
        #
        # And of course, we will not need to worry about any items
        # which have empty values.  If the shopper did not enter a
        # quantity, then we won't add it to the cart.

        if ( ( $item =~ /^item-/i || $item =~ /^option/i ) && $form_data{$item} ) {

            # Once the script has determined that the current element
            # ($item) of @items_ordered is indeeed a non-admin item,
            # it must separate out the items that have been ordered
            # from the options which modify those items.  If $item
            # begins with the keyword "option", which we set
            # specifically in the HTML file, the script will add
            # (push) that item to the array called @options.  However,
            # before we make the check, we must strip the "item-"
            # keyword off the item so that we have the actual row
            # number for comparison.

            $item =~ s/^item-//i;

            if ( $item =~ /^option/i ) {

                # Donation Mode
                if ( ( $sc_donation_mode eq 'yes' ) && ( $item =~ /^option\|donationAmount/ ) && ( $sc_use_verified_opt_values eq 'no' ) ) {
                    if ( ( $form_data{$item} ne '' ) && ( $form_data{$item} !~ /notused/i ) && ( $form_data{$item} !~ /\-1/ ) ) {
                        $form_data{$item} = $sc_donation_option_display_name . '|' . $form_data{$item};
                    }
                }

                push( @options, $item );
            }

            # On the other hand, if it is not an option, the script adds
            # it to the array @items_ordered_with_options, but adds
            # both the item and its value as a single array element.
            #
            # The value will be a quantity and the item will be
            # something like "item-0001|12.98|The letter A" as defined in
            # the HTML file.  Once we extract the initial "item-"
            # tag from the string using regular expressions ($item =~
            # s/^item-//i;), the resulting string would be something
            # like the following:
            #
            #           2|0001|12.98|The letter A
            #
            # where 2 is the quantity.
            #
            # Firstly, it must be a digit ($form_data{$item} =~ /\D/).
            # That is, we do not want the clients trying to enter
            # values like "a", "-2", ".5" or "1/2".  They might be
            # able to play havok on the ordering system and a sneaky
            # client may even gain a discount because you were not
            # reading the order forms carefully.
            #
            # This is no longer true, zero is OK:
            # Secondly, the script will dissallow any zeros
            # ($form_data{$item} == 0).  In both cases the client will
            # be sent to the subroutine bad_order_note

            else {
                $form_data{"item-$item"} =~ s/ //g;    # get rid of any blanks
                if ( (
                           ( $form_data{"item-$item"} =~ /\D/ )
                        && ( $form_data{"item-$item"} =~ /.?/g ) && ( !($sc_ignore_bad_qty_on_add) )
                    )
                    || ( $form_data{"item-$item"} < 0 )
                  )
                {
                    if ( !($sc_ignore_bad_qty_on_add) ) {
                        $need_bad_order_note = 1;
                    }
                }

                else {
                    $quantity = $form_data{"item-$item"};
                    if ( $quantity > 0 ) {

                        # official inventory plug-in routines
                        if ( ($sc_db_index_for_inventory) && ( $mc_mgr_plugins_enabled =~ /inventory_control/ ) )   {
                            $failed = subtract_inventory( $item, $quantity );
                        }
                        if ($failed) {
                            $need_bad_order_note = 1;
                        }
                        else {
                            push( @items_ordered_with_options,
                                "$quantity\|$item\|" );
                            $order_count++;
                        }
                    }
                }

            }

            # End of if ($item ne "$variable" && $form_data{$item} )
        }

        #End of foreach $item (@items_ordered)
    }

    if ( ( $order_count == 0 ) or ($need_bad_order_note) ) {

        # need to exit, nothing to do actually
        $sc_shall_i_let_client_know_item_added = 'no';    # force this
          # remove our cart modifier, so a page re-post won't generate the message
        $temp = get_agora('TRANSACTIONS');
        @temp = split( /\n/, $temp );
        $junk = pop(@temp);
        if ( $junk eq $sc_unique_cart_modifier ) {
            $temp = join( "\n", @temp ) . "\n";
            set_agora( 'TRANSACTIONS', $temp );
        }
        if ($need_bad_order_note) {
            bad_order_note();
        }
        elsif ( $form_data{"add_to_cart_button"} && !( $form_data{"item-$item"} ) ) {
            $sc_bad_order_note_alt = $agora_error_add2cart_out_of_stock_safty_net;
            bad_order_note();
        }
        else {
            finish_add_to_the_cart();
        }
        return;
    }

    # Now the script goes through the array
    # @items_ordered_with_options one item at a time in order
    # to modify any item which has had options applied to it.
    # Recall that we just built the @options array with all
    # the options for all the items ordered.  Now the script
    # will need to figure out which options in @options belong
    # to which items in @items_ordered_with_options.

    foreach my $item_ordered_with_options (@items_ordered_with_options)   {

        codehook( 'foreach_item_ordered_top' );

        # First, clear out a few variables that we are going to
        # use for each item.
        #
        # $options will be used to keep track of all of the
        # options selected for any given item.
        #
        # $option_subtotal will be used to determine the total
        # cost of each option.
        #
        # $option_grand_total will be used to calculate the
        # total cost of all ordered options.
        #
        # $item_grand_total will be used to calculate the total
        # cost of the item ordered factoring in quantity and
        # options.

        $options            = q{};
        $option_subtotal    = q{};
        $option_grand_total = q{};
        $item_grand_total   = q{};

# Now split out the $item_ordered_with_options into it's
# fields.  Note that we have defined the index location of
# some important fields in agora_setup.pl  Specifically,
# the script must know the index of quantity, item_id and
# item_price within the array.  It will need these values
# in particular for further calculations.  Also, the
# script will change all occurances of "~qq~" to a double
# quote (") character, "~gt~" to a greater than sign (>)
# and "~lt~" to a less than sign (<).  The reason that
# this must be done is so that any double quote, greater
# than, or less than characters used in URLK strings can
# be stuffed safely into the cart and passed as part of
# the NAME argumnet in the "add item" form.  Consider the
# following item name which must include an image tag.
#
# <INPUT TYPE = "text"
#        NAME = "item-0010|Vowels|15.98|The letter A|~lt~IMG SRC = ~qq~Html/Images/a.jpg~qq~ ALIGN = ~qq~left~qq~~gt~"
# >
# Notice that the URL must be edited. If it were not, how
# would the browser understand how to interpret the form
# tag?  The form tag uses the double quote, greater
# than, and less than characters in its own processing.

        $item_ordered_with_options =~ s/~qq~/\"/g;
        $item_ordered_with_options =~ s/~gt~/\>/g;
        $item_ordered_with_options =~ s/~lt~/\</g;    # >

        my @cart_row = split( /\|/, $item_ordered_with_options );

        codehook('foreach_item_ordered_split_cart_row');

        $web_id_number = $cart_row[$sc_cart_index_of_item_id];
        if ( $sc_web_pid_sep_char ne '' ) {
            ( $cart_row[$sc_cart_index_of_item_id], $junk ) =
              split( /$sc_web_pid_sep_char/,
                $cart_row[$sc_cart_index_of_item_id], 2 );
            $item_id_number     = $cart_row[$sc_cart_index_of_item_id];
            $wildcard_id_number = $item_id_number . $sc_web_pid_sep_char . '*';
        }
        else {
            $item_id_number     = $cart_row[$sc_cart_index_of_item_id];
            $wildcard_id_number = q{};
        }
        $item_quantity       = $cart_row[$sc_cart_index_of_quantity];
        $item_price          = $cart_row[$sc_cart_index_of_price];
        $item_shipping       = $cart_row[ $cart{'shipping'} ];
        $item_option_numbers = q{};
        $item_user1          = q{};
        if ( $sc_use_downloads =~ /fullyloaded/i ) {
            my $data_field_thingy = "$sc_download_user_index";
            $item_user2 = check_db_with_product_id_for_info( $item_id_number, $data_field_thingy, *database_fields );
        }
        else {
            $item_user2 = q{};
        }

        #make one read on alt origin and dimensional thingies
        # add in alt origin state or province  by Mister Ed May 22, 2007
        if ( ( $sc_alt_origin_enabled =~ /yes/i )
            || ( $sc_dimensional_shipping_enabled =~ /yes/i ) )  {
            my $shipping_string = get_prod_shipping_dimensions_in_db_row($item_id_number);
            my @shippingstuff = split( /\,/, $shipping_string );

            if ( $sc_alt_origin_enabled =~ /yes/i ) {
                $item_user3 = "$shippingstuff[6],$shippingstuff[7]";
            }
            else {
                $item_user3 = q{};
            }

            if ( $sc_dimensional_shipping_enabled =~ /yes/i ) {
                $item_user5 = "$shippingstuff[0],$shippingstuff[1],$shippingstuff[2],$shippingstuff[3],$shippingstuff[4],$shippingstuff[5]";
            }
            else {
                $item_user5 = q{};
            }
            undef(@shippingstuff);
        }    # End if alt origin OR dimensions

        # taxable or non-table. added by Mister Ed Sept 13, 2005
        if ( $sc_non_taxables_enabled =~ /yes/i ) {
            my $data_field_thingy = "$sc_non_taxables_db_counter";
            $item_user4 =  check_db_with_product_id_for_info( $item_id_number, $data_field_thingy, *database_fields );
        }
        else {
            $item_user4 = q{};
        }

        $item_user6       = q{};
        $item_agorascript = q{};
        undef(%item_opt_verify);

        # need to lookup options add-to-cart type agorascript, if present in
        # option file(s)

        $found = check_db_with_product_id( $item_id_number, *database_fields );
        create_display_fields(@database_fields);

        codehook('cart_add_read_db_item');

        foreach my $zzzitem (@database_fields) {
            my $field = $zzzitem;
            if ( $field =~ /^%%OPTION%%/i ) {
                ( $empty, $option_tag, $option_location ) =
                  split( /%%/, $field );

                $field = load_opt_file($option_location);

                # do %%token%% substitution and exec runtime agorascript
                # so that option value verification is possible
                $junk = option_prep( $field, $option_location, $item_id_number );
                $junk = prep_displayProductPage($junk);

                # save entire thing for later potential execution of agorascript
                $item_agorascript .= $field;

            }   # End of if ($field =~ /^%%OPTION%%/)
        }
        codehook('cart_add_read_item_agorascript');

        # Then for every option in @options, the script splits up
        # each option into it's fields.
        #
        # Once it does both splits, the script can compare the name
        # of the item with the name associated with the option.
        # If they are the same, it knows that this is an option
        # which was meant to enhance this item.
        EACHOPTIONVALUE:
        foreach my $option (@options) {
            ( $option_marker, $option_number, $option_item_number ) =
              split( /\|/, $option );

            # If the script finds a match, it records the option
            # information contained in the $option variable.

            if (   ( $option_item_number eq "$web_id_number" )
                || ( $option_item_number eq "$wildcard_id_number" ) )
            {

               # Since it must apply this option to this item, the script
               # splits out the value associated with the option and
               # appends it to $options.  Once it has gone through all of
               # the options, using .=, the script will have one big string
               # containing all the options so that it can print them
               # out. Note that in the form on which the client chooses
               # options, each option is denoted with the form
               #
               #            NAME = "a|b|c" VALUE = "d|e|f"
               #
               # where
               #
               # a is the option marker "option"
               # b is the option number (you might have multiple options
               #       which all modify the same item.  Option number
               #       identifies each option uniquely)
               # c is the option item number (the unique item id number
               #       which the option modifies)
               # d is the option name (the descriptive name of the
               #       option)
               # e is the option price.
               #
               # f is the option shipping amount added to shipping costs of item
               #
               # For example, consider this option from the default
               # Vowels.html file which modifies item number 0001:
               #
               #      <INPUT TYPE = "radio" NAME = "option|2|0001"
               #             VALUE = "Red|0.00" CHECKED>Red<BR>
               #
               # This is the second option modifying item number 0001.
               # When displayed in the display cart screen, it will read
               # "Red 0.00, and will not affect the cost of the item.

      # need to process specific add-to-cart-opt type agorascript, if present in
      # option file(s)
                $field =
                  agorascript( $item_agorascript,
                    'add-to-cart-opt-' . $option_number,
                    "$option_location", __FILE__, __LINE__ );

                ( $option_name, $option_price, $option_shipping ) =
                  split( /\|/, $form_data{$option} );

                if ( ( 0 + $option_price ) == 0 )  {    #price zero, do not display it
                    $display_option_price = q{};
                }
                elsif ( ( $sc_negative_priced_options ne 'no' )
                    && ( ( 0 + $option_price ) < '0' ) )
                {

               # Added by Mister Ed at BytePipe.com / AgoraCart.com 2-18-2004.
               # if negative priced options disallowed, prevent addition to cart

                    if ( $item_user1 eq '' ) {
                        $killitemthingy = 'yes';
                        options_error_message();
                        exit;
                    }
                }
                else {    # price non-zero, must format it
                          # Added by Mister Ed August 9, 2006
                     # toggles display of options pricing.  now can be turned off
                    $display_option_price = " " . display_price($option_price);
                    if ( $sc_turn_off_option_price_display =~ /off/i ) {
                        $display_option_price = q{};
                    }
                }

                if ($option_name) {

# Updated by Mister Ed at BytePipe.com / AgoraCart.com Feb-18-2004.  Now works and not just dead code
                    if ( $sc_use_verified_opt_values =~ /yes/i ) {
                        my $option_name_temp = "$option_name";
                        $option_name_temp =~ s/\(/\\(/g;
                        $option_name_temp =~ s/\)/\\)/g;

                        # looks inside options file opened above.
                        if (   $field =~ /$option_name_temp\|$option_price/  || $field =~ /$option_name_temp\|$option_price\|$option_shipping/  )  {
                            $temp = $form_data{$option};
                        }
                        elsif ( $item_user1 ) {
                            $temp = $form_data{$option};
                        }
                        else {
                            $option_name    = q{};     # erase it, unverifiable
                            $killitemthingy = 'yes';
                            $sc_unique_cart_modifier_orig = q{};
                            $sc_unique_cart_modifier      = q{};
                            $option_price                 = q{};
                            options_error_message();
                            exit;
                        }
                    }
                    else {
                        $temp = $form_data{$option};
                    }
                    if ($option_name)
                    {    # still here, either verified or not doing verification
                         # Keep track of the numbers chosen and their value
                        $temp =~ s/\|/~/g; # cannot have pipes, change to ~ char
                        if ( $item_option_numbers eq '' ) {
                            $item_option_numbers = "${option_number}*$temp";
                        }
                        else {
                            $item_option_numbers .= $sc_opt_sep_marker . "${option_number}*$temp";
                        }

                        if ( $options) {
                            $options .= "$sc_opt_sep_marker";
                        }
                        $options .= "$option_name$display_option_price";
                    }
                }

                # But the script must also calculate the cost changes with
                # options. To do so, it will take the current value of
                # $option_grand_total and add to it the value of the
                # current option.  It will then format the result to
                # two decimal places using the format_price subroutine
                # discussed later and assign the new result to
                # $option_grand_total

                codehook('process_cart_options');

                if ( $killitemthingy ne 'yes' ) {
                    $item_shipping = $item_shipping + $option_shipping;
                    $unformatted_option_grand_total = $option_grand_total + $option_price;
                    $option_grand_total = format_price($unformatted_option_grand_total);
                }    # end of skip if $killitemthingy

                # End of if ($option_item_number eq "$item_id_number")
            }

            # End of foreach $option (@options)
        }

        # Next, calculate $item_number which the script can use to
        # identify a shopping cart item absolutely.  This must be done
        # so that when we modify and delete from the cart, we will
        # know exactly which item to affect. We cannot rely simply
        # on the unique database id number because a client may
        # purchase two of the same item but with different
        # options. Unless there is a separate, unique cart row id
        # number, how would the script know which to delete if the
        # client asked to delete one of the two. Add 1 to
        # $highest_item_number, which was set at the beginning of
        # the subroutine.

        if ( $killitemthingy ne 'yes' ) {
            $item_number = ++$highest_item_number;

            # Finally, the script makes the last price calculations
            # and appends every ordered item to $cart_row
            #
            # A completed cart row might look like the following:
            # 2|0001|Vowels|15.98|Letter A|Times New Roman 0.00|15.98|161

            $unformatted_item_grand_total = $item_price + $option_grand_total;
            $item_grand_total = format_price("$unformatted_item_grand_total");

            # now, make the cart value for shipping be the shipping with options
            $cart_row[ $cart{'shipping'} ]           = $item_shipping;
            $cart_row[ $cart{'shipping_calc_flag'} ] = q{};

            # Add the id #s of the options too
            $cart_row[ $cart{'options_ids'} ] = $item_option_numbers;

           # need to process generic add-to-cart type agorascript, if present in
           # option file(s)
            $field = agorascript( $item_agorascript, 'add-to-cart', "$option_location", __FILE__, __LINE__ );

            codehook('before_build_cart_row');

            $cart_row[ $cart{"user1"} ] = $item_user1; # variable options
            $cart_row[ $cart{"user2"} ] = $item_user2; # downloadable
            $cart_row[ $cart{"user3"} ] = $item_user3; # alt origin for shipping
            $cart_row[ $cart{"user4"} ] = $item_user4; # non-taxable status
            $cart_row[ $cart{"user5"} ] = $item_user5; # dimensional shipping data
            $cart_row[ $cart{"user6"} ] = $item_user6; # available
            foreach $field (@cart_row) {
                $cart_row .= "$field\|";
            }

            $cart_row .= "$options\|$item_grand_total";
            ( $cart_row_qty, $cart_row_middle ) = split( /\|/, $cart_row, 2 );
            $cart_row .= "\|$item_number\n";
            # End of foreach $item_ordered_with_options.....

            codehook('foreach_item_ordered_end');

            add_one_row_to_cart( $cart_row, $cart_row_qty, $cart_row_middle );

            $cart_row = q{};

        }

        #last, set any special variable options thingies, if present
        update_special_variable_options('calculate');
    }    # End of skip if $killitemthingy
         # Then, the script sends the client back to a previous
         # page.  There are two pages that the customer can be sent
         # of course, the last product page they were on or the
         # page which displays the customer's cart.  Which page the
         # customer is sent depends on the value of
         # $sc_should_i_display_cart_after_purchase which is defined
         # in managers by store admin.  If the customer should be sent to
         # the display cart page, the script calls
         # display_cart_contents, otherwise it calls display_page
         # if this is an HTML-based cart or
         # create_html_page_from_db if this is a database-based
         # cart.

    finish_add_to_the_cart();

}

#######################################################################
#                       finish_add_to_the_cart
#######################################################################

sub finish_add_to_the_cart {

    codehook( 'finish_add_to_the_cart' );

    agora_cookie_save();

    if ( $sc_should_i_display_cart_after_purchase_real eq 'viewCart' ) {
        $sc_should_i_display_cart_after_purchase = 'viewCart';
    }
    elsif ( $sc_should_i_display_cart_after_purchase_real eq 'checkOut' ) {
        $sc_should_i_display_cart_after_purchase = 'checkOut';
    }

    if (   ( $sc_use_html_product_pages =~ /yes/i )
        || ( ( $sc_use_html_product_pages =~ /maybe/i ) && ( $page ) ) )
    {
        if ( $sc_should_i_display_cart_after_purchase eq 'viewCart' ) {
            display_cart_contents();
        }
        else {
            display_page( "$sc_html_product_directory_path/$page",'Display Products for Sale' );
        }
    }
    else {
        if ( $sc_should_i_display_cart_after_purchase eq 'viewCart' ) {
            display_cart_contents();
        }
        elsif ( $sc_should_i_display_cart_after_purchase eq 'checkOut' ) {
            #fake checkout button submit
            $form_data{'order_form_button.x'} = 1;
            $form_data{'order_form_button'} = 1;
            #&print_agora_http_headers();
            require_supporting_libraries( __FILE__, __LINE__, "$sc_display_orderform_path" );
            &load_product_libs;
            &load_cart_libs;
            display_order_form();
            agora_cookie_save();
            call_exit();
        }
        elsif ( $are_any_query_fields_filled_in =~ /yes/i ) {
            $page = '';
            display_products_for_sale();
        }
        else {
            create_html_page_from_db();
        }    # end of else
    }    # end of top/first if conditional

}

#######################################################################

sub add_one_row_to_cart {

    local ( $cart_row, $cart_row_qty, $cart_row_middle ) = @_;
    local ( @lines, @newlines, @testme, $qty, $orig_line, $line );

    # When it is done appending all the items to $cart_row,
    # the script appends the new items to the end of the
    # shopping cart, which was opened at the beginning of the subroutine.
    # DELUXE feature: only new items added, otherwise quanitites added

    codehook('before_add_cart_rows');

    if ( -e "$sc_cart_path" ) {
        open( CART, "$sc_cart_path" ) || file_open_error(
            "$sc_cart_path", "$agora_error_logging_notice02", __FILE__, __LINE__
        );
        @lines = (<CART>);
        close(CART);
        open( CART, ">$sc_cart_path" ) || file_open_error(
            "$sc_cart_path", "$agora_error_logging_notice02",__FILE__,__LINE__
        );
        local (@newlines) = ();
        foreach $line (@lines) {
            $orig_line = $line;
            ( $qty, $line ) = split( /\|/, $line, 2 );
            (@testme) = split( /\|/, $line );
            $line_no = pop(@testme);
            $line = join( '|', @testme );
            if ( $line eq $cart_row_middle ) {
                $orig_line =
                  ( $qty + $cart_row_qty ) . '|' . $line . '|' . $line_no;
                $cart_row_middle = q{};
            }
            push( @newlines, $orig_line );
        }
        if ( $cart_row_middle ) {
            push( @newlines, $cart_row );
        }
        @newlines =
          ( sort { middle_of_cart($a) <=> middle_of_cart($b) } @newlines );
        foreach $line (@newlines) {
            print CART "$line";
        }
        close(CART);
    }
    else {
        open( CART, ">$sc_cart_path" ) || file_open_error(
            "$sc_cart_path", "$agora_error_logging_notice02", __FILE__, __LINE__
        );
        print CART "$cart_row";
        close(CART);
    }
    codehook('after_add_cart_rows');

}

#######################################################################

sub middle_of_cart {
    local ($line) = @_;
    local ( $qty, @testme, $line_no );
    ( $qty, $line ) = split( /\|/, $line, 2 );
    (@testme) = split( /\|/, $line );
    $line_no = pop(@testme);
    $line = join( '|', @testme );
    return $line;
}

#######################################################################
#                Modify Quantity of Items in the Cart
#######################################################################
#
# The modify_quantity_of_items_in_cart subroutine is
# responsible for making quantity modifications in the
# customer's cart.  It takes no arguments and as called
# with the following syntax:
#
# modify_quantity_of_items_in_cart();
#
#######################################################################

sub modify_quantity_of_items_in_cart {

    checkReferrer();    # now only tests for repeats as of 4.0L

    # First, the script gathers the keys as it did for the
    # add_to_cart routine previously, checking to make
    # sure the customer entered a positive integer (not
    # fractional and not less than one).

    local @incoming_data = keys(%form_data);
    local $failed = '';

    foreach $key (@incoming_data) {
        if (   ( $key =~ /[\d]/ )
            && ( $form_data{$key} =~ /\D/ )
            && ( !( $form_data{$key} < 0 ) )
            && ( !( $form_data{$key} > 0 ) ) )
        {
            $form_data{$key} = q{};
        }

        # Just as the script did in the add to cart routine
        # previuosly, it will create an array (@modify_items) of
        # valid keys.

        unless ( $key =~ /[\D]/ && $form_data{$key} =~ /[\D]/ ) {
            if ( ( $form_data{$key} ) || ( $form_data{$key} eq 0 ) ) {
                push( @modify_items, $key );
            }
        }

        # End of foreach $key (@incoming_data)
    }

    # Then, the script must open up the client's cart and go
    # through it line by line.  File open problems are
    # handled by file_open_error as usual.

    open( CART, "<$sc_cart_path" ) || file_open_error(
        "$sc_cart_path", "$agora_error_logging_notice03",__FILE__,  __LINE__
    );

    # As the script goes through the cart, it will split each
    # row into its database fields placing them as elements in
    # @database_row.  It will then grab the unique cart row
    # number and subsequently replace it in the array.
    #
    # The script needs this number to check the current line
    # against the list of items to be modified. Recall that
    # this list will be made up of all the cart items which
    # are being modified.
    #
    # The script also grabs the current quantity of that row.
    # Since it is not yet sure if it wants the current
    # quantity, it will hold off on adding it back to the
    # array.  Finally, the script chops the newline character
    # off the cart row number.

    while (<CART>) {
        @database_row = split( /\|/, $_ );
        $inventory_pid = $database_row[1];
        $cart_row_number = pop(@database_row);
        push( @database_row, $cart_row_number );
        $old_quantity = shift(@database_row);
        chop $cart_row_number;

        # Next, the script checks to see if the item number
        # submitted as form data is equal to the number of the
        # current database row.

        foreach $item (@modify_items) {

            if ( $item eq $cart_row_number ) {
                # inventory update
                if ( ($sc_db_index_for_inventory) && ( $sc_inventory_subtract_at_add_to_cart =~ /yes/i ) )    {
                    my $update_qty = $form_data{$item} - $old_quantity;
                    $failed = subtract_inventory( $inventory_pid, $update_qty );
                    if ( $failed ) {
                        &bad_order_note();
                    }
                }

                # If so, it means that the script must change the quantity
                # of this item.  It will append this row to the
                # $shopper_row variable and begin creating the modified
                # row.  That is, it will replace the old quantity with the
                # quantity submitted by the client ($form_data{$item}).
                # Recall that $old_quantity has already been shifted off
                # the array.

               # if negative value entered, "subtract" from old value
               # same if, for example, +6 is entered, add 6 to the current value
                if ( $form_data{$item} =~ /\-/ ) {
                    $form_data{$item} =~ s/\-//g;
                    $form_data{$item} = 0 - $form_data{$item};
                }
                if (   ( $form_data{$item} < 0 )
                    || ( $form_data{$item} =~ /\+/ ) )
                {
                    codehook('item_quantity_to_be_modified');
                    $form_data{$item} =~ s/\+//g;
                    $form_data{$item} = $old_quantity + $form_data{$item};
                }
                if (   ( $form_data{$item} eq '' )
                    || ( $form_data{$item} < 1 ) )
                {
                    codehook('item_quantity_to_be_modified');
                    $form_data{$item} = $old_quantity - $old_quantity - 1;
                }

                # if invalid qty entered, removes item
                $form_data{$item} = 0 + $form_data{$item};

                # if negative or zero, then delete the item from the cart
                if ( $form_data{$item} le 0 ) {
                    $shopper_row .= "\|";    #this forces a deletion from CART
                }
                else {
                    $shopper_row .= "$form_data{$item}\|";

                    # Now the script adds the rest of the database row to
                    # $shopper_row and sets two flag variables.
                    #
                    # $quantity_modified lets us know that the current row
                    # has had a quantity modification for each iteration of
                    # the while loop.

                    foreach my $field (@database_row) {
                        $shopper_row .= "$field\|";
                    }
                }

                $quantity_modified = 'yes';
                codehook('item_quantity_modified');
                chop $shopper_row;    # Get rid of last pipe symbol but not the
                                      # newline character

                # End of if ($item eq $cart_row_number)
            }

            # End of foreach $item (@modify_items)
        }

        # If the script gets this far and $quantity_modified has
        # not been set to "yes", it knows that the above routine
        # was skipped because the item number submitted from the
        # form was not equal to the curent database id number.
        #
        # Thus, it knows that the current row is not having its
        # quantity changed and can be added to $shopper_row as is.
        # Remember, we want to add the old rows as well as the new
        # modified ones.

        if ( $quantity_modified ne 'yes' ) {
            $shopper_row .= $_;
        }

        # Now the script clears out the quantity_modified variable
        # so that next time around it will have a fresh test.

        $quantity_modified = q{};

        # End of while (<CART>)
    }

    close(CART);

    # At this point, the script has gone all the way through
    # the cart.  It has added all of the items without
    # quantity modifications as they were, and has added all
    # the items with quantity modifications but made the
    # modifications.
    #
    # The entire cart is contained in the $shopper_row
    # variable.
    #
    # The actual cart still has the old values, however.  So
    # to change the cart completely the script must overwrite
    # the old cart with the new information and send the
    # client back to the view cart screen with the
    # display_cart_contents subroutine which will be discussed
    # later. Notice the use of the write operator (>) instead
    # of the append operator (>>).

    open( CART, ">$sc_cart_path" ) || file_open_error(
        "$sc_cart_path", "$agora_error_logging_notice03", __FILE__, __LINE__
    );

    print CART "$shopper_row";

    close(CART);

    # process any special qty discounts
    update_special_variable_options('calculate');

    codehook('modify_quantity_of_items_in_cart_bot');

    finish_modify_quantity_of_items_in_cart();

    # End of if ($form_data{'submit_change_quantity'} ne "")
}

#######################################################################

sub finish_modify_quantity_of_items_in_cart {
    #$sc_calculate_shipping_at_display_form = $sc_calculate_shipping_loop;
    #$sc_calculate_discount_at_display_form = $sc_calculate_discount_loop;
    codehook('finish_modify_quantity_of_items_in_cart');
    display_cart_contents();
}

#######################################################################
#                 Delete Item From Cart
#######################################################################
#
# The job of delete_from_cart is to take a set of items
# submitted by the user for deletion and actually delete
# them from the customer's cart.  The subroutine takes no
# arguments and is called with the following syntax:
#
# delete_from_cart();
#
#######################################################################

sub delete_from_cart {

    checkReferrer();    # now only tests for repeats as of 4.0L

    # As with the modification routines, the script first
    # checks for valid entries. This time though it only needs
    # to make sure that it filters out the extra form
    # keys rather than make sure that it has a positive
    # integer value as well because unlike with a text entry,
    # clients have less ability to enter bad values with
    # checkbox submit fields.

    local @incoming_data = keys(%form_data);
    foreach my $key (@incoming_data) {

        # We still want to make sure that the key is a cart row
        # number though and that it has a value associated with
        # it. If it is actually an item which the user has asked to
        # delete, the script will add it to the delete_items
        # array.

        unless ( $key =~ /[\D]/ ) {
            if ( $form_data{$key} ) {
                push( @delete_items, $key );
            }

            # End of unless ($key =~ /[\D]/...
        }

        # End of foreach $key (@incoming_data)
    }

    # Once the script has gone through all the incomming form
    # data and collected the list of all items to be deleted,
    # it opens up the cart and gets the $cart_row_number,
    # $db_id_number, and $old_quantity as it did in the
    # modification routines previously.

    open( CART, "<$sc_cart_path" ) || file_open_error(
        "$sc_cart_path", "$agora_error_logging_notice04", __FILE__, __LINE__
    );

    while (<CART>) {
        @database_row = split( /\|/, $_ );
        $inventory_pid = $database_row[1];
        $cart_row_number = pop(@database_row);
        $db_id_number    = pop(@database_row);
        push( @database_row, $db_id_number );
        push( @database_row, $cart_row_number );
        chop $cart_row_number;
        $old_quantity = shift(@database_row);

        # Unlike modification however, for deletion all we need to
        # do is check to see if the current database row matches
        # any submitted item for deletion.  If it does not match
        # the script adds it to $shopper_row.  If it is equal,
        # it does not. Thus, all the rows will be added to
        # $shopper_row except for the ones that should be deleted.

        my $delete_item = q{};
        foreach $item (@delete_items) {

            if ( $item eq $cart_row_number ) {
                $delete_item = 'yes';
                codehook('mark_item_for_delete');
            }

            # End of foreach $item (@add_items)
        }

        if ( $delete_item ne $sc_yes ) {
            $shopper_row .= $_;
        }    # inventory updates
        elsif (($sc_db_index_for_inventory)  && ( $sc_inventory_subtract_at_add_to_cart =~ /yes/i ) )  {
            add_inventory( $inventory_pid, $old_quantity );
        }

        # End of while (<CART>)
    }

    close(CART);

    # Then, as it did for modification, the scipt overwrites
    # the old cart with the new information and
    # sends the client back to the view cart page with the
    # display_cart_contents subroutine which will be discussed
    # later.

    open( CART, ">$sc_cart_path" ) || file_open_error(
        "$sc_cart_path", "$agora_error_logging_notice04",__FILE__, __LINE__
    );

    print CART "$shopper_row";
    close(CART);

    finish_delete_from_cart();

    # End of if ($form_data{'submit_deletion'})
}

#######################################################################

sub finish_delete_from_cart {
    codehook( 'finish_delete_from_cart' );
    update_special_variable_options('calculate');
    $sc_calculate_shipping_at_display_form = $sc_calculate_shipping_loop;
    display_cart_contents();
}

#######################################################################
#                   display_cart_contents Subroutine
#######################################################################
#
# display_cart_contents is used to display the current
# contents of the customer's cart.  It takes no arguments
# and is called with the following syntax:
#
# display_cart_contents();
#
#######################################################################

sub display_cart_contents {

    local ( $my_gt, $my_tq, $tmq, $st ) = q{};
    local (@cart_fields);
    local (
        $field,      $cart_id_number,       $quantity,
        $display_number,     $unformatted_subtotal, $subtotal,
        $unformatted_grand_total, $grand_total,   $taxable_grand_total
    );
    local $skip_cart_contents_table = '';

    if ( $sc_global_bot_tracker ne '1' ) {    # run only if not a bot

        codehook( 'display_cart_contents_top' );

        standard_page_header('View/Modify Cart');

        # override showing cart contents, but still do calculations
        if ( $skip_cart_contents_table && $sc_donation_mode eq 'yes' ) {
            ( $taxable_grand_total, $my_gt, $my_tq, $tmq, $st ) = dont_display_cart_table();
        }
        else {
            ( $taxable_grand_total, $my_gt, $my_tq, $tmq, $st ) = display_cart_table();
        }

        codehook('display_cart_contents_bottom');

        cart_footer( ( 0 + $my_gt ), ( 0 + $my_tq ) );
        agora_cookie_save();
        call_exit();
    }

}

#######################################################################
#                    cart_table_header Subroutine
#######################################################################
#
# cart_table_header is used to generate the header
# HTML for views of the cart.  It takes one argument, the
# type of view we are requesting and is called with the
# following syntax:
#
# cart_table_header(TYPE OF REQUEST);
#
#######################################################################

sub cart_table_header {

    local ($modify_type) = @_;
    local $cell_type = '';

    codehook( 'cart_table_header_top' );

    # We take modify_type and make it into a table header if
    # it has a value. If it does not have a value, then we
    # don't want to output a needless column.  There are
    # really only four values that modify type should be
    # equal to:
    #
    # 1. "" (View/Modify Cart or Order Form Screen)
    # 2. "New Quantity" (Change Quantity Form)
    # 3. "Delete Item" (Delete Item Form)
    # 4. "Verify" or "Process Order" (Order Form Process Confirmation)
    #
    # These four types distinguish the five types of pages on
    # which a cart will be displayed.  We need to know these
    # values in order to determine if there will be an extra
    # table header in the cart display.  In the case of
    # quantity changes or delete item forms, there must be an
    # extra table cell for the checkbox and textfield inputs
    # so that the customer can select items.  In the
    # View/Modify cart screen ($modify_type ne ""), no extra
    # cell is necessary.

    if ( $modify_type ) {

        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
            $modify_type = "<th>$modify_type</th>";
        }
        else {
            my $temp = $sc_cart_item_header_cell_modifier;
            $temp =~ s/\[\[modifytype\]\]/$modify_type/;
            $modify_type = $temp;
        }

        codehook( 'display_cart_heading_modify_item' );
    }
    elsif ( ($sc_use_enhanced_cart_view_buttons ne 'no') && ($form_data{'dc'} || $form_data{'submit_deletion_button.x'} || $form_data{'submit_deletion_button'} || $form_data{'submit_change_quantity_button'} || $form_data{'add_to_cart_button'} || $form_data{'show_simple_option_form'} || $form_data{'submit_simple_option_form'} || $form_data{'order_form_button.x'} || $form_data{'order_form_button'} || $form_data{'submit_order_form_button'}) )
    {

        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
            $modify_type = $sc_cart_item_header_cell_2_legacy;
        }
        else {
            $modify_type = $sc_cart_item_header_cell_2;
            $modify_type =~ s/\[\[modifytype\]\]/$agora_cart_table02b/;
        }
    }

    if ( $reason_to_display_cart =~ /orderform/i ) {
        CheckoutStoreHeader();
        $sc_order_form_page_header_title_box =~ s/\[\[order_form_page_header_text\]\]/$agora_order_form_page_title_text/g;
        print $sc_order_form_page_header_title_box;
    }
    elsif ( $reason_to_display_cart =~ /verify/i ) {
        CheckoutStoreHeader();
        $sc_verify_page_header_title_box =~ s/\[\[verify_page_header_text\]\]/$agora_verify_page_title_text/g;
        print $sc_verify_page_header_title_box;
    }
    else {
        StoreHeader();
    }

    $hidden_fields = make_hidden_fields();

    codehook( 'cart_table_header' );

    if ( $special_message ) {
        print $special_message;
    }

    # buysafe adjustment
    if ( ( $reason_to_display_cart =~ /orderform/i ) || ( $reason_to_display_cart =~ /verify/i ) ) {
        $sc_table_form_type_2 =~ s/\[\[sc_cart_contents_table_width\]\]/$sc_cart_contents_table_width/;
        print $sc_table_form_type_2;
    }
    else {
        print $sc_table_form_type_1;
        print $sc_cart_page_header_box;
    }

    print $hidden_fields;

    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
      print $sc_cart_items_table_lagacy;
    }
    else {
      print $sc_cart_items_table;
    }

    # @sc_cart_display_fields is the list of all of the table
    # headers to be displayed in the cart display table and is
    # defined in the manager

    my $temp_index = '0';
    foreach $field (@sc_cart_display_fields) {

        codehook('display_cart_heading_item');

        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
          if (
              !(
                     ( $sc_col_name[$temp_index] eq 'web_options' )
                  || ( $sc_col_name[$temp_index] eq 'options' )
                  || ( $sc_col_name[$temp_index] eq 'email_options' )
              )
            )
          {
              $cart_heading_item = "<th>$field</th>\n";
              print $cart_heading_item;
          }

          $temp_index++;

        }
        else {
          if ( !(
                ( $sc_col_name[$temp_index] eq 'web_options' )
                  || ( $sc_col_name[$temp_index] eq 'options' )
                  || ( $sc_col_name[$temp_index] eq 'email_options' )
              ) )
          {
              if ( ( $sc_col_name[$temp_index] =~ /image/ ) || ( $sc_col_name[$temp_index] =~ /user1/ ) )  {
                  $cell_type = q| cart-cont-image|;
              }
              elsif ( $sc_col_name[$temp_index] =~ /name/ ) {
                  $cell_type = q| cart-cont-name|;
              }
              elsif ( $sc_col_name[$temp_index] =~ /quantity/ ) {
                  $cell_type = q| cart-cont-qty|;
              }
              elsif ( $sc_col_name[$temp_index] =~ /shipping/ ) {
                  $cell_type = q| cart-cont-shipping|;
              }
              elsif ( $sc_col_name[$temp_index] =~ /price/ ) {
                  $cell_type = q| cart-cont-price|;
              }
              $cart_heading_item = qq|<div class="cart-contents-cell$cell_type"><b>$field</b></div>\n|;
              print $cart_heading_item;
          }

          $temp_index++;

      }


    }
    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
        print $modify_type;
    }
    else {
      print $modify_type . "\n";
      print "</div><!-- thead -->\n\n"
    }

    # We'll also add on table headers for Quantity and Subtotal.

}

#######################################################################
#                    display_cart_table Subroutine
#######################################################################
#
# The job of display_cart_table is to display the current
# contents of the user's cart for several diffferent
# types of screens which all display the cart in some form
# or another.  The subroutine takes one argument, the
# reason that the cart is being displayed, and is called
# with the following syntax:
#
# display_cart_table("reason");
#
# There are really only five values that
# $reason_to_display_cart should be equal to:
#
# 1. "" (View/Modify Cart Screen)
# 2. "changequantity" (Change Quantity Form)
# 3. "delete" (Delete Item Form)
# 4. "orderform" (Order Form)
# 5. "verify" (Order Form Process Confirmation)
#
# Notice that this corresponds closely to the list in
# cart_table_header because the goal of this subroutine is
# to fill in the actual cells of the table created by
# cart_table_header.
#
#######################################################################

sub display_cart_table {

    # Working variables are initialized and defined as local
    # to this subroutine.  Don't mess with these definitions.

    local ($reason_to_display_cart) = @_;
    local ( $cart_id_number, $cart_line_id )= q{};
    local ( $unformatted_subtotal, $subtotal ) = q{};
    local ( $unformatted_grand_total, $grand_total ) = q{};
    local ( $stevo_shipping_thing ) = q{};
    local ( $total_quantity, $total_measured_quantity ) = 0;
    local ( $counter, $display_me, $found_it ) = q{};
    local ( $hidden_field_name, $hidden_field_value, $display_counter ) = q{};
    local ( $product_id, @db_row );

    # taxable or non-table. added by Mister Ed Sept 13, 2005
    local ($isTaxable) = q{};
    local ($unformatted_taxable_grand_total) = 0;
    local ($taxable_grand_total) = 0;

    # Next the script determines which type of cart display it
    # is being asked to produce.  It uses pattern matching to
    # look for key phrases in the ($reason_to_display_cart
    # defined as an incoming argument.  Whatever the case, the
    # subroutine calls cart_table_header to begin outputting
    # the HTML cart display.

    codehook( 'display_cart_top' );

    if ( $sc_global_bot_tracker ne '1' ) {    # run only if not a bot

        cart_table_header();

        # Next, the client's cart is read line by line (file open
        # errors handled by file_open_error as usual).

        if ( !( -f "$sc_cart_path" ) ) {    #doesn't exist, create a null file
            open( CART, ">$sc_cart_path" )
              || file_open_error(
                "$sc_cart_path", 'display_cart_contents create null file',__FILE__,__LINE__
              );
            close(CART);
        }

        # If it cannot be read, then there is a problem
        open( CART, "$sc_cart_path" )
          || file_open_error( "$sc_cart_path", "display_cart_contents",__FILE__, __LINE__ );


        while (<CART>) {

            # Since every line in the cart will be displayed as a cell
            # in an HTML table, we begin by outputting an opening
            # <TR> tag.

            if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                print q|</tr><tr>|;
            }
            else {
                  print qq|<div class="trow">\n|;
            }

            # Next, the current line has it's final newline charcater
            # chopped off.

            chomp;

            # Then, the script splits the row in the client's cart
            # and grabs the unique product ID number, the unique cart
            # id number, and the quantity. We will use those values
            # while processing the cart.

            my $temp    = $_;
            local @cart_fields     = split( /\|/, $temp );
            local $cart_row_number = pop(@cart_fields);
            push( @cart_fields, $cart_row_number );
            $cart_copy{$cart_row_number} = $temp;

            codehook( 'display_cart_row_read' );

            local $quantity   = $cart_fields[ $cart{'quantity'} ];
            local $product_id = $cart_fields[ $cart{'product_id'} ];

            # taxable or non-table. added by Mister Ed Sept 13, 2005
            $isTaxable = $cart_fields[ $cart{'user4'} ];

            # Next we will need to begin to distinguish between types
            # of displays we are being asked for because each type of
            # display is slightly different. For example, if we are
            # being asked to display a cart for the delete item
            # form, we will need to add a checkbox before each item so
            # that the customer can select which items to delete.  If,
            # on the other hand, we are being asked for modify the
            # quantity of an item form, we need to add a text field
            # instead, so that the customer can enter a new quantity.
            #
            # The first case we will handle is if we are being asked
            # to display the cart as part of order processing.

# DELUXE version ... we need the database row loaded for virtual cart
# fields.  If a cart field is less than 0, it is assumed to be
# a field from the database instead of the cart.
#
# If we are displaying the cart for order
# processing AND we are checking the
# database to make sure that the product being
# ordered is OK, then we need to load the
# database libraries if they have not been
# required already.

            if ( !( $sc_db_lib_was_loaded =~ /yes/i ) ) {
                require_supporting_libraries( __FILE__, __LINE__, "$sc_db_lib_path" );
            }

            # Then, we call the check_db_with_product_id
            # in the database library. If it returns
            # false, then we output a footer
            # complaining about the problem and
            # exit the program.

            # load the row for use with virtual fields ...
            undef(@db_row);
            $found_it = check_db_with_product_id( $product_id, *db_row );

            codehook( 'display_cart_db_row_read' );

            my $item_agorascript = q{};

           # need to lookup options display-cart type agorascript, if present in
           # option file(s)
            foreach my $zzzitem (@db_row) {
                my $field = $zzzitem;
                if ( $field =~ /^%%OPTION%%/i ) {
                    ( $empty, $option_tag, $option_location ) = split( /%%/, $field );
                    $field = load_opt_file($option_location);
                    $item_agorascript .= $field;
                    # End of if ($field =~ /^%%OPTION%%/)
                }
            }
            codehook( 'display_cart_item_agorascript' );
            my $zzfield =
              agorascript( $item_agorascript, 'display-cart', "$product_id",__FILE__, __LINE__ );

            if (   ( $reason_to_display_cart =~ /orderform/i ) && ( $sc_order_check_db =~ /yes/i ) )   {
                if ( !($found_it) ) {
                    $sc_errors_widget_cart_items =~ s/\[\[error_message\]\]/$agora_error_message07$product_id $agora_error_message08/;
                    print $sc_errors_widget_cart_items;
                    call_exit();
                }

                # Otherwise, we check the returned row
                # with the price of the product in the
                # cart. If the prices do not match
                # then another complaint message is printed
                # and we exit the program.

                else {

  # if ($db_row[$sc_db_index_of_price] ne $cart_fields[$sc_cart_index_of_price])
                    my $test_price =
                      vf_get_data( 'PRODUCT', $sc_db_price_field_name,
                        $db_row[$sc_db_index_of_product_id], @db_row );
                    if ( $test_price ne $cart_fields[$sc_cart_index_of_price] ) {
                        $sc_errors_widget_cart_items =~ s/\[\[error_message\]\]/$agora_error_message10$product_id $agora_error_message10/;
                        print $sc_errors_widget_cart_items;
                        call_exit();
                    }

                    # End of Else
                }

                # End of if (($reason_to_display_cart =~ /process.*order/i)...
            }

            # Remember, we need to use the display_table_cart
            # to keep track of totals such as quantity, subtotal,
            # and total measured quantity.
            #
            # Directly below, we keep track of total quantity.

            $total_quantity += $quantity;

            # $display_counter is set equal to zero.  This variable
            # will be used for

            my $display_counter = 0;

            # Now, for every item in the cart row which should be
            # displayed as defined in the setup file, we
            # will display the data as a table cell.
            #
            # However, there are three types of data which must be
            # displayed in table cells but which must be formatted
            # slightly differently.
            #
            # The first type of cell is a cell with no data.  To give
            # the table a nice three dimensional look to it, we will
            # substitute all occurances of no data for the &nbsp;
            # character in order to get a blank but indented table
            # cell.  Of course, this routine simply overwrites the
            # empty value of the data with the &nbsp; character, it
            # does not actually display the cell...instead, it passes
            # that job on to the next if test.
            #
            # Another case is when a table cell must reflect a price.
            # In that case we must format the data with the monetary
            # symbol defined in store manager setups.
            #
            # Finally, non price table cells are displayed (including
            # those passed down from the first case.

            my $temp_fieldname_indicator = q{};
            foreach my $field_name (@sc_col_name) {
                if (   ( $field_name eq 'web_options' )
                    || ( $field_name eq 'options' )
                    || ( $field_name eq 'email_options' ) )
                {
                    $temp_fieldname_indicator = '1';
                }
            }
            my $temp_index = '0';
            foreach my $field_name (@sc_col_name) {
                my $display_name = $sc_cart_display_fields[$temp_index];
                my $display_index = $cart{$field_name};
                my $cart_cell = '';
                $display_me = '';
                my $cart_line_id  = $cart_fields[ $cart{'unique_cart_line_id'} ];
                # Reformat blank cells.
                if ( $display_index >= 0 ) {
                    $display_me =
                      vf_get_data( 'CART', $field_name, $cart_line_id,
                        @cart_fields );
                    if ( $sc_cart_display_factor[$display_counter] =~ /yes/i ) {
                        $display_me = $display_me * $quantity;
                    }

                }
                # Display various cells
                $sc_display_special_request = 0;
                $zzfield = agorascript( $item_agorascript,'display-cart-' . $display_index,"$product_id", __FILE__, __LINE__ );
                codehook( 'cart_table_special_request_decision' );    # decide, and perhaps act





                if ( !( $sc_display_special_request == 0 ) ) {
                    codehook( 'cart_table_special_request' );    # optional second crack at it
                }
                elsif ( $field_name eq 'quantity' ) {
                    if ( $reason_to_display_cart )  {
                        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                            print  qq!<td>$display_me</td>\n!;
                        }
                        else {
                            $cart_cell = $sc_cart_contents_table{'QTY Cell with reason'};
                            $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                            $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                            print $cart_cell;
                        }

                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'QTY Cell'};
                        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                            $cart_cell = $sc_cart_contents_table{'Table Common Cells'};
                        }

                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                        $cart_cell =~ s/\[\[cartrownumber\]\]/$cart_row_number/g;
                        print $cart_cell;
                    }
                }
                elsif ( $display_index == $sc_cart_index_of_price ) {
                    $price = display_price($display_me);
                    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                        print qq!<td>$price</td>\n!;
                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Price or Total Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$price/;
                        print $cart_cell;
                    }
                }

                elsif ( $display_index == $sc_cart_index_of_price_after_options ) {
                  #This one includes the shipping field times quantity
                  #$lineTotal = &format_price(($quantity*$cart_fields[$display_index])+
                  # ($cart_fields[0]*$cart_fields[6]));
                  #
                  #This one is without shipping
                    $lineTotal = format_price($display_me);
                    $lineTotal = display_price($lineTotal);
                    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                        print qq!<td>$lineTotal</td>\n!;
                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Price or Total Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$lineTotal/;
                        print $cart_cell;
                    }
                }

                # Empty - skipped. v6+
                # But kept to skip email/web/option fields as they were now used elsewhere.
                elsif (( $field_name eq 'web_options' )
                    || ( $field_name eq 'options' )
                    || ( $field_name eq 'email_options' ) )
                {}

                #virtual cart value
                elsif ( $display_index <  0 ) {
                    $display_me = $db_row[ ( 0 - $display_index ) ];    # lookup the proper field
                    if ( $sc_cart_display_factor[$display_counter] =~ /yes/i ) {
                        $display_me = $display_me * $quantity;
                    }

                    my $temp = $field_name;
                    if ( $temp eq 'db_description' ) { $temp = 'product' }
                    elsif ( $temp eq 'db_user1' ) { $temp = 'image' }

                    # if field starts with [[IMG]] then it is an image, and will will generate an HTML IMG tag for it
                    if ( $display_me =~ /^\[\[img\]\]/i ) {
                        ( $image_tag, $image_location ) = split( /\]\]/, $display_me );
                        $display_me =
                            '<img src="'
                          . "$URL_of_images_directory/$image_location"
                          . '" alt="'
                          . "$image_location" . '">';

                    } elsif ( $display_me =~ /^%%IMG%%/i ) {
                        ( $empty, $image_tag, $image_location ) = split ( /%%/, $display_me );
                        $display_me = '<img src="'
                        . "$URL_of_images_directory/$image_location"
                        . '" alt="' . "$image_location" . '">';
                    }
                    if ( $temp =~ /image/ ) {
                        if ( $sc_use_cart_contents_images eq 'yes' ) {
                            # fix images from non-DB add-to-cart in certain situations
                            $display_me = $cart_fields[5];
                        }
                        $display_me =~ s/\[\[URLofImages\]\]/$URL_of_images_directory/g;
                        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                            print qq!<td>$display_me</td>\n!;
                        }
                        else {
                            $cart_cell = $sc_cart_contents_table{'Mini Image Cell'};
                            $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                            $cart_cell =~ s/\[\[productID\]\]/$product_id/;
                            $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                            print $cart_cell;
                        }
                    }
                    elsif ( $temp =~ /shipping/ ) {
                        if ( $sc_use_SBW =~ /yes/i ) {
                            $display_me = $display_me;
                        }
                        else {    # display total price
                            $display_me = display_price($display_me);
                        }

                        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                            print qq!<td>$display_me</td>\n!;
                        }
                        else {
                            $cart_cell = $sc_cart_contents_table{'Shipping Cell'};
                            $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                            $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                            print $cart_cell;
                        }
                    }
                    else {
                        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                            print qq!<td>$display_me</td>\n!;
                          }
                        else {
                            $cart_cell = $sc_cart_contents_table{'Generic TD type Cell'};
                            $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                            $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                            print $cart_cell;
                        }
                    }

                }

                elsif ( $display_index == $sc_cart_index_of_image ) {
                    my $imagestring = $sc_small_cart_display_image;
                    $display_me = $cart_fields[$display_index];
                    $imagestring =~ s/\[\[image\]\]/$display_me/ig;
                    $display_me = $imagestring;
                    $display_me =~ s/\[\[URLofImages\]\]/$URL_of_images_directory/g;

                    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                        print qq!<td>$display_me</td>\n!;
                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Mini Image Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[productID\]\]/$product_id/;
                        $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                        print $cart_cell;
                    }
                }

                elsif ( $display_index == $sc_cart_index_of_measured_value ) {
                    if ( $sc_use_SBW =~ /yes/i ) {    #display total pounds
                        $shipping_price = $display_me;
                    }
                    else {                            # display total price
                        $shipping_price = display_price($display_me);
                    }
                    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                        print qq!<td>$shipping_price</td>\n!;
                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Shipping Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$shipping_price/;
                        print $cart_cell;
                    }
                }

                elsif ( $field_name eq 'name' ) {
                    if ( ( $temp_fieldname_indicator eq '1' ) && ( $cart_fields[15] ) ) {
                        my @ans_opts =
                          split( /$sc_opt_sep_marker/, $cart_fields[15] );
                        my $ans2 = join "$sc_cart_table_optionline_setup",
                          @ans_opts;
                        if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                            $cart_cell = $sc_cart_contents_table{'Table Row with Options Legacy'};
                        }
                        else {
                            $cart_cell = $sc_cart_contents_table{'Product Name with Options Cell'};
                        }

                        $cart_cell =~ s/\[\[optionanswer\]\]/$sc_cart_table_optionline_setup $ans2/;

                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Product Name Cell'};
                    }

                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$display_me/g;
                    $cart_cell =~ s/\[\[productID\]\]/$product_id/;
                    print $cart_cell;

                }

                # Display all other cells (blank cells have already been reformatted)
                else {
                    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
                        print qq!<td>$display_me</td>\n!;
                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Generic TD type Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                        print $cart_cell;
                    }
                }

                # If the current display index happens to be a cell which
                # must be measured, we will add the value to
                # $total_measured_quantity for later calculation and
                # display.

                $display_counter++;
                $temp_index++;

                # End of foreach $display_index (@sc_cart_index_for_display)
            }

            # create the shipping info for SBW module and totals
            $total_measured_quantity = $total_measured_quantity + $quantity * $cart_fields[6];
            $shipping_total = $total_measured_quantity;

            # alt origin postal code adds postal code to stevo for shipping by Mister Ed Feb 9, 2005
            # added alt origin state/prov by Mister Ed May 22, 2007
            if ( $sc_alt_origin_enabled =~ /yes/i ) {
                my ( $zip, $stateprov, $junk ) =
                  split( /\,/, $cart_fields[11], 3 );
                $stevo_shipping_thing .= '|'
                  . $quantity . '*'
                  . $cart_fields[6] . '*'
                  . $cart_fields[$sc_cart_index_of_price_after_options] . '*'
                  . $zip . '*'
                  . $stateprov . '*';
            }
            else {
                $stevo_shipping_thing .= '|'
                  . $quantity . '*'
                  . $cart_fields[6] . '*'
                  . $cart_fields[$sc_cart_index_of_price_after_options] . '*'
                  . '*' . '*';
            }

            # dimensional shipping data added to stevo for shipping by Mister Ed May 17, 2007
            if ( $sc_dimensional_shipping_enabled =~ /yes/i ) {
                $stevo_shipping_thing .= $cart_fields[13];
            }

            # Then we will need to use the quantity value we shifted
            # earlier to fill the next table cell, and then, after
            # using another database specific setup variable,
            # calculate the subtotal for that database row and fill
            # the final cell and close out the table row and the cart
            # file (once we have gone all the way through it.)

            $unformatted_subtotal =  ( $cart_fields[$sc_cart_index_of_price_after_options] );
            $subtotal = format_price( $quantity * $unformatted_subtotal );
            $unformatted_grand_total = $grand_total + $subtotal;
            $grand_total   = format_price($unformatted_grand_total);

            # taxable or non-table. added by Mister Ed Sept 13, 2005
            if ( $isTaxable !~ /yes/i ) {
                $unformatted_taxable_grand_total = $taxable_grand_total + $subtotal;
                $taxable_grand_total =  format_price($unformatted_taxable_grand_total);
            }

            $price = display_price($subtotal);



            if ( $sc_display_v5v6_legacy_cart_contents_header ne 'yes' ) {

                $cart_cell = $sc_cart_contents_table{'Remove Item Cell'};
                $cart_cell =~ s/\[\[formdataproduct\]\]/$form_data{'product'}/;
                $cart_cell =~ s/\[\[formdatakeywords\]\]/$form_data{'keywords'}/;
                $cart_cell =~ s/\[\[cartrownumber\]\]/$cart_row_number/g;
                $cart_cell =~ s/\[\[cartid\]\]/$cart_id/;
                print $cart_cell;

                print $sc_cart_item_trow_end_tags;

            }

            # End of while (<CART>)
        }

        close(CART);

        # For now, assume this value is correct.  If SBW or others change it
        # then they need to set this variable independently
        $sc_shipping_thing = $shipping_total . $stevo_shipping_thing;

        $sc_cart_copy_made = 'yes';

        # Finally, print out the footer with the cart_footer
        # subroutine in web_store.html.

        $price = display_price($grand_total);

        $shipping_total = display_price($shipping_total);

        if ( $reason_to_display_cart =~ /verify/i ) {
            print qq!<input type="hidden" name="total" value="$grand_total">!;
        }

        cart_table_footer($price, '', $reason_to_display_cart);

        if ( $reason_to_display_cart =~ /verify/i ) {
            display_calculations( $taxable_grand_total, $grand_total, 'at', $total_measured_quantity );
        }
        else {
            display_calculations( $taxable_grand_total, $grand_total, 'before', $total_measured_quantity );
        }

        # We need to return the subtotal for those routines such
        # as ordering calculations
        #
        # We also need to return the text of the cart in case we
        # are logging orders to email or to a file

        return ( $taxable_grand_total, $grand_total, $total_quantity,
            $total_measured_quantity, $stevo_shipping_thing );

    }    # end of "run only if not a bot"

    #End of display_cart_table
}

######################################################################
#                    dont_display_cart_table Subroutine
#######################################################################
#
# The job of dont_display_cart_table is to sstrip out the cart contents display
# table for donation or other sites that do not want to display the cart information.
# However we stil need the data, so this is run instead.
# Same as display_cart_table but without the print output.
#
#######################################################################

sub dont_display_cart_table {

    # Working variables are initialized and defined as local
    # to this subroutine.  Don't mess with these definitions.

    local ($reason_to_display_cart) = @_;
    local ( $cart_id_number, $cart_line_id )= q{};
    local ( $unformatted_subtotal, $subtotal ) = q{};
    local ( $unformatted_grand_total, $grand_total ) = q{};
    local ( $stevo_shipping_thing ) = q{};
    local ( $total_quantity, $total_measured_quantity ) = 0;
    local ( $counter, $display_me, $found_it ) = q{};
    local ( $hidden_field_name, $hidden_field_value, $display_counter ) = q{};
    local ( $product_id, @db_row );
    local ($isTaxable) = q{};
    local ($unformatted_taxable_grand_total) = 0;
    local ($taxable_grand_total) = 0;

    codehook( 'dont_display_cart_top' );

    if ( $sc_global_bot_tracker ne '1' ) {    # run only if not a bot

        if ( $reason_to_display_cart =~ /orderform/i ) {
            CheckoutStoreHeader();
            $sc_order_form_page_header_title_box =~ s/\[\[order_form_page_header_text\]\]/$agora_order_form_page_title_text/g;
            print $sc_order_form_page_header_title_box;
        }
        elsif ( $reason_to_display_cart =~ /verify/i ) {
            CheckoutStoreHeader();
            $sc_verify_page_header_title_box =~ s/\[\[verify_page_header_text\]\]/$agora_verify_page_title_text/g;
            print $sc_verify_page_header_title_box;
        }
        else {
            StoreHeader();
        }

        $hidden_fields = make_hidden_fields();

        codehook( 'cart_table_header' );

        if ( $special_message ) {
            print $special_message;
        }

        # buysafe adjustment
        if ( ( $reason_to_display_cart =~ /orderform/i ) || ( $reason_to_display_cart =~ /verify/i ) ) {
            print $sc_table_form_type_3;
        }
        else {
            print $sc_table_form_type_1;
            print $sc_cart_page_header_box_no_show;
        }

        print $hidden_fields;

        # Next, the client's cart is read line by line (file open
        # errors handled by file_open_error as usual).

        # Next, the client's cart is read line by line (file open
        # errors handled by file_open_error as usual).

        if ( !( -f "$sc_cart_path" ) ) {    #doesn't exist, create a null file
            open( CART, ">$sc_cart_path" )
              || file_open_error(
                "$sc_cart_path", 'display_cart_contents create null file',__FILE__,__LINE__
              );
            close(CART);
        }

        # If it cannot be read, then there is a problem
        open( CART, "$sc_cart_path" ) || file_open_error( "$sc_cart_path", "display_cart_contents",__FILE__, __LINE__ );

        while (<CART>) {

            # Next, the current line has it's final newline charcater
            # chopped off.

            chomp;

            # Then, the script splits the row in the client's cart
            # and grabs the unique product ID number, the unique cart
            # id number, and the quantity. We will use those values
            # while processing the cart.

            my $temp = $_;
            local @cart_fields = split( /\|/, $temp );
            local $cart_row_number = pop(@cart_fields);
            push( @cart_fields, $cart_row_number );
            $cart_copy{$cart_row_number} = $temp;

            codehook( 'display_cart_row_read' );

            my $quantity   = $cart_fields[ $cart{'quantity'} ];
            my $product_id = $cart_fields[ $cart{'product_id'} ];

            # taxable or non-table.
            $isTaxable = $cart_fields[ $cart{'user4'} ];

            # Next we will need to begin to distinguish between types
            # of displays we are being asked for because each type of
            # display is slightly different. For example, if we are
            # being asked to display a cart for the delete item
            # form, we will need to add a checkbox before each item so
            # that the customer can select which items to delete.  If,
            # on the other hand, we are being asked for modify the
            # quantity of an item form, we need to add a text field
            # instead, so that the customer can enter a new quantity.
            #
            # The first case we will handle is if we are being asked
            # to display the cart as part of order processing.

            # We need the database row loaded for virtual cart
            # fields.  If a cart field is less than 0, it is assumed to be
            # a field from the database instead of the cart.
            #
            # If we are displaying the cart for order
            # processing AND we are checking the
            # database to make sure that the product being
            # ordered is OK, then we need to load the
            # database libraries if they have not been
            # required already.

            if ( !( $sc_db_lib_was_loaded =~ /yes/i ) ) {
                require_supporting_libraries( __FILE__, __LINE__, "$sc_db_lib_path" );
            }

            # Then, we call the check_db_with_product_id
            # in the database library. If it returns
            # false, then we output a footer
            # complaining about the problem and
            # exit the program.

            # load the row for use with virtual fields ...
            undef(@db_row);
            $found_it = check_db_with_product_id( $product_id, *db_row );

            codehook( 'display_cart_db_row_read' );

            my $item_agorascript = q{};

           # need to lookup options display-cart type agorascript, if present in
           # option file(s)
            foreach my $zzzitem (@db_row) {
                my $field = $zzzitem;
                if ( $field =~ /^%%OPTION%%/i ) {
                    ( $empty, $option_tag, $option_location ) = split( /%%/, $field );
                    $field = load_opt_file($option_location);
                    $item_agorascript .= $field;
                    # End of if ($field =~ /^%%OPTION%%/)
                }
            }
            codehook( 'display_cart_item_agorascript' );
            my $zzfield =
              agorascript( $item_agorascript, 'display-cart', "$product_id",__FILE__, __LINE__ );

            if (   ( $reason_to_display_cart =~ /orderform/i ) && ( $sc_order_check_db =~ /yes/i ) )   {
                if ( !($found_it) ) {
                    $sc_errors_widget_cart_items =~ s/\[\[error_message\]\]/$agora_error_message07$product_id $agora_error_message08/;
                    print $sc_errors_widget_cart_items;
                    call_exit();
                }

                # Otherwise, we check the returned row
                # with the price of the product in the
                # cart. If the prices do not match
                # then another complaint message is printed
                # and we exit the program.

                else {

                    # if ($db_row[$sc_db_index_of_price] ne $cart_fields[$sc_cart_index_of_price])
                    my $test_price =
                      vf_get_data( 'PRODUCT', $sc_db_price_field_name,
                        $db_row[$sc_db_index_of_product_id], @db_row );
                    if ( $test_price ne $cart_fields[$sc_cart_index_of_price] ) {
                        $sc_errors_widget_cart_items =~ s/\[\[error_message\]\]/$agora_error_message10$product_id $agora_error_message10/;
                        print $sc_errors_widget_cart_items;
                        call_exit();
                    }

                    # End of Else
                }

                # End of if (($reason_to_display_cart =~ /process.*order/i)...
            }

            # Directly below, we keep track of total quantity.

            $total_quantity += $quantity;

            # $display_counter is set equal to zero.  This variable
            # will be used for

            my $display_counter = 0;

            # Now, for every item in the cart row which should be
            # displayed as defined in the setup file, we
            # will display the data as a table cell.
            #

            my $temp_fieldname_indicator = q{};
            foreach my $field_name (@sc_col_name) {
                if (   ( $field_name eq 'web_options' )
                    || ( $field_name eq 'options' )
                    || ( $field_name eq 'email_options' ) )
                {
                    $temp_fieldname_indicator = '1';
                }
            }
            my $temp_index = '0';
            foreach my $field_name (@sc_col_name) {
                my $display_name = $sc_cart_display_fields[$temp_index];
                my $display_index = $cart{$field_name};
                my $cart_cell = '';
                $display_me = '';
                my $cart_line_id  = $cart_fields[ $cart{'unique_cart_line_id'} ];
                # Reformat blank cells.
                if ( $display_index >= 0 ) {
                    $display_me =
                      vf_get_data( 'CART', $field_name, $cart_line_id,
                        @cart_fields );
                    if ( $sc_cart_display_factor[$display_counter] =~ /yes/i ) {
                        $display_me = $display_me * $quantity;
                    }

                }
                # Display various cells
                $sc_display_special_request = 0;
                $zzfield = agorascript( $item_agorascript,'display-cart-' . $display_index,"$product_id", __FILE__, __LINE__ );
                codehook( 'cart_table_special_request_decision' );    # decide, and perhaps act

                if ( !( $sc_display_special_request == 0 ) ) {
                    codehook( 'cart_table_special_request' );    # optional second crack at it
                }

                elsif ( $display_index == $sc_cart_index_of_price ) {
                    $price = display_price($display_me);
                }

                elsif ( $display_index == $sc_cart_index_of_price_after_options ) {
                  #This one includes the shipping field times quantity
                  #$lineTotal = &format_price(($quantity*$cart_fields[$display_index])+
                  # ($cart_fields[0]*$cart_fields[6]));
                  #
                  #This one is without shipping
                    $lineTotal = format_price($display_me);
                    $lineTotal = display_price($lineTotal);
                }

                #virtual cart value
                elsif ( $display_index <  0 ) {
                    $display_me = $db_row[ ( 0 - $display_index ) ];    # lookup the proper field
                    if ( $sc_cart_display_factor[$display_counter] =~ /yes/i ) {
                        $display_me = $display_me * $quantity;
                    }

                    my $temp = $field_name;
                    if ( $temp eq 'db_description' ) { $temp = 'product' }
                    elsif ( $temp eq 'db_user1' ) { $temp = 'image' }
                    elsif ( $temp =~ /shipping/ ) {
                        if ( $sc_use_SBW =~ /yes/i ) {
                            $display_me = $display_me;
                        }
                        else {    # display total price
                            $display_me = display_price($display_me);
                        }
                    }

                }
                elsif ( $display_index == $sc_cart_index_of_measured_value ) {
                    if ( $sc_use_SBW =~ /yes/i ) {    #display total pounds
                        $shipping_price = $display_me;
                    }
                    else {                            # display total price
                        $shipping_price = display_price($display_me);
                    }
                }

                elsif ( $field_name eq 'name' ) {
                    if ( ( $temp_fieldname_indicator eq '1' ) && ( $cart_fields[15] ) ) {
                        my @ans_opts =
                          split( /$sc_opt_sep_marker/, $cart_fields[15] );
                        my $ans2 = join "$sc_cart_table_optionline_setup",
                          @ans_opts;
                    }
                }

                # If the current display index happens to be a cell which
                # must be measured, we will add the value to
                # $total_measured_quantity for later calculation and
                # display.

                $display_counter++;
                $temp_index++;

                # End of foreach $display_index (@sc_cart_index_for_display)
            }

            # create the shipping info for SBW module and totals
            $total_measured_quantity = $total_measured_quantity + $quantity * $cart_fields[6];
            $shipping_total = $total_measured_quantity;

            # alt origin postal code adds postal code to stevo for shipping by Mister Ed Feb 9, 2005
            # added alt origin state/prov by Mister Ed May 22, 2007
            if ( $sc_alt_origin_enabled =~ /yes/i ) {
                my ( $zip, $stateprov, $junk ) =
                  split( /\,/, $cart_fields[11], 3 );
                $stevo_shipping_thing .= '|'
                  . $quantity . '*'
                  . $cart_fields[6] . '*'
                  . $cart_fields[$sc_cart_index_of_price_after_options] . '*'
                  . $zip . '*'
                  . $stateprov . '*';
            }
            else {
                $stevo_shipping_thing .= '|'
                  . $quantity . '*'
                  . $cart_fields[6] . '*'
                  . $cart_fields[$sc_cart_index_of_price_after_options] . '*'
                  . '*' . '*';
            }

            # dimensional shipping data added to stevo for shipping by Mister Ed May 17, 2007
            if ( $sc_dimensional_shipping_enabled =~ /yes/i ) {
                $stevo_shipping_thing .= $cart_fields[13];
            }

            # Then we will need to use the quantity value we shifted
            # earlier to fill the next table cell, and then, after
            # using another database specific setup variable,
            # calculate the subtotal for that database row and fill
            # the final cell and close out the table row and the cart
            # file (once we have gone all the way through it.)

            $unformatted_subtotal =  ( $cart_fields[$sc_cart_index_of_price_after_options] );
            $subtotal = format_price( $quantity * $unformatted_subtotal );
            $unformatted_grand_total = $grand_total + $subtotal;
            $grand_total   = format_price($unformatted_grand_total);

            # taxable or non-table. added by Mister Ed Sept 13, 2005
            if ( $isTaxable !~ /yes/i ) {
                $unformatted_taxable_grand_total = $taxable_grand_total + $subtotal;
                $taxable_grand_total =  format_price($unformatted_taxable_grand_total);
            }

            $price = display_price($subtotal);

            # End of while (<CART>)
        }

        close(CART);

        # For now, assume this value is correct.  If SBW or others change it
        # then they need to set this variable independently
        $sc_shipping_thing = $shipping_total . $stevo_shipping_thing;

        $sc_cart_copy_made = 'yes';

        # Finally, print out the footer with the cart_footer
        # subroutine in web_store.html.

        $price = display_price($grand_total);

        $shipping_total = display_price($shipping_total);

        if ( $reason_to_display_cart =~ /verify/i ) {
            print qq!<input type="hidden" name="total" value="$grand_total">!;
        }

        cart_table_footer($price, '', $reason_to_display_cart);

        if ( $reason_to_display_cart =~ /verify/i ) {
            display_calculations( $taxable_grand_total, $grand_total, 'at', $total_measured_quantity );
        }
        else {
            display_calculations( $taxable_grand_total, $grand_total, 'before', $total_measured_quantity );
        }

        # We need to return the subtotal for those routines such
        # as ordering calculations
        #
        # We also need to return the text of the cart in case we
        # are logging orders to email or to a file

        return ( $taxable_grand_total, $grand_total, $total_quantity,
            $total_measured_quantity, $stevo_shipping_thing );

    }    # end of "run only if not a bot"

    #End of dont_display_cart_table
}

#######################################################################
#                    cart_table_footer Subroutine
#######################################################################
#
# empty cart footer message added.  Closing table cells added to closing
# table tag as well by Mister Ed (K-Factor Technologies, Inc) 10/17/2003

# cart_table_footer is used to display the footer for cart
# table displays.  It takes one argumnet, the pre shipping
# grand total and is called with the following syntax:
#
#  cart_table_footer($price);
#
#######################################################################

sub cart_table_footer {
    local ( $price, $shipping_total, $reason_to_display_cart ) = @_;
    local ($footer);
    if ( $price == 0 ) {
        print $sc_empty_cart_footer_msg;
    }
    if ( $sc_display_v5v6_legacy_cart_contents_header eq 'yes' ) {
      $footer = qq~</tr></table>
  </div>
~;
    }

    if ( ( $reason_to_display_cart =~ /orderform/i ) || ( $reason_to_display_cart =~ /verify/i ) ) {
        $footer = qq~</div></div></div>~;
    }
    else {
        $footer = qq~</div></div>~;
    }

    codehook( 'cart_table_footer' );

    print $footer;

}

#######################################################################
#                       cart_footer Subroutine                        #
#######################################################################
# cart_footer is used to generate the HTML footer
# code for the "view items in the cart" form
# page.  It takes no arguments and is called with the
# following syntax:
#
# cart_footer();
#
# As usual, we will admit the "Return to Frontpage" button
# only if we are not using frames by defining it with the
# $sc_no_frames_button in agora_messages.pl.

sub cart_footer {
    local ( $grand_total, $quantity ) = @_;
    local $footer  = q{};

    # Use the empty cart footer if it is there and qty=0
    my $file_title = "$sc_cartPlates_dir/$sc_empty_cart_footer_file";
    if ( ( $quantity > 0 ) || ( !( -f $file_title ) ) ) {
        $file_title = "$sc_cartPlates_dir/$sc_full_cart_footer_file";
    }

    open( CARTFOOTER, "$file_title" ) || file_open_error( "$sc_cart_path", 'cartfooter', __FILE__, __LINE__ );

    while (<CARTFOOTER>) {
        $footer .= $_;
    }
    close CARTFOOTER;
    $footer = script_and_substitute_footer($footer);

    codehook('cart_footer');

    print $footer;
    StoreFooter();

}

#######################################################################

1;
