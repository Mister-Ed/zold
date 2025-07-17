$versions{'misc_cart_helpers.pl'} = '06.6.00.0001';

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


#########################################################################
#                         Alias and Override
#
# This routine allows the use of aliases for switches, such as
# using xm= instead of exact_match=
#
# Also, override certain setup variables under certain conditions
#
#########################################################################

sub alias_and_override {
    local ( $item,    $xx );
    local ( $junk,    $raw_text ) = '';
    local ( @mylibs,  $lib );
    local ( $testval, $testval2, $found_response );

    #codehook( 'alias_and_override_top' );

    # Check for payment gateway responses - may not be required
    $found_response = q{};
    foreach $testval ( keys %sc_order_response_vars ) {
        $testval2 = $sc_order_response_vars{$testval};
        if ( $form_data{$testval2} ) {
            $found_response = 1;
        }
    }
    if (   ( ("$sc_domain_name_for_cookie" ne $ENV{'HTTP_HOST'} ) && ( $sc_stepone_order_script_url !~ /$ENV{'HTTP_HOST'}/ ) )
        && ( $sc_allow_location_redirect =~ /yes/i )
        && ( $form_data{'process_order'}  eq '' )
        && ( $form_data{'process_order.x'}  eq '' )
        && ( $form_data{'relay'}  eq '' )
        && ( $found_response  eq '' )
        && ( $form_data{'submit_order_form_button'}  eq '' )
        && ( $form_data{'submit_order_form_button.x'}  eq '' )
        && ( $form_data{'order_form_button.x'}  eq '' )
        && ( $form_data{'order_form_button'}  eq '' ) )
    {    #redirect them to standard URL

        $sc_cart_path = "$sc_user_carts_directory_path/${cart_id}_cart";
        if ( !( -f $sc_cart_path ) ) {    #no cart, forget the number
            $cart_id = '';
        }
        $href = "$sc_store_url";
        if ( $cart_id ) {
            $href .= "?cart_id=$cart_id";
        }
        print "Location: $href\n\n";
        call_exit();
    }

    if ( defined( $form_data{'srb'} ) && ( $form_data{'search_request_button'} eq '' ) ) {
        $form_data{'search_request_button'} = $form_data{'srb'};
    }
    elsif ( defined( $form_data{'search_request_button'} ) && ( $form_data{'srb'} eq '' ) ) {
        $form_data{'srb'} = $form_data{'search_request_button'};
    }
    if ( ( $form_data{'maxp'} > 0 ) && ( $form_data{'maxp'} < 251 ) ) {
        $sc_db_max_rows_returned = $form_data{'maxp'};
    }
    if ( defined( $form_data{'srb'} ) ) {    #is an override/shortcut
        $search_request = $form_data{'srb'};
    }
    if ( defined( $form_data{'xc'} ) ) {
        $form_data{'exact_case'} = $form_data{'xc'};
    }
    if ( defined( $form_data{'xm'} ) ) {
        $form_data{'exact_match'} = $form_data{'xm'};
    }
    if ( defined( $form_data{'dc'} ) ) {
        $form_data{'display_cart'} = $form_data{'dc'};
    }
    if ( defined( $form_data{'pid'} ) ) {
        $form_data{'p_id'} = $form_data{'pid'};
    }
    if ( defined( $form_data{'ofn'} ) ) {
        $form_data{'order_form'} = $form_data{'ofn'};
    }
    if ( defined( $form_data{'p'} ) ) {
        if ( $form_data{'product'}) {
            $form_data{'product'} .= " " . $form_data{'p'};
        }
        else {
            $form_data{'product'} = $form_data{'p'};
        }
    }

    if ( defined( $form_data{'k'} ) ) {
        if ( $form_data{'keywords'}) {
            $form_data{'keywords'} .= " " . $form_data{'k'};
        }
        else {
            $form_data{'keywords'} = $form_data{'k'};
        }
    }

    if ( ( $form_data{'add_to_cart_button'} eq '' )
        && ( $form_data{'add_to_cart_button.x'} )
        ) {
            $form_data{'add_to_cart_button'} = '1';
    }


    if ( $form_data{'viewOrder'} eq 'yes') {
        $sc_should_i_display_cart_after_purchase = 'yes';
    }
    else {
        $sc_should_i_display_cart_after_purchase = 'no';
    }

    if ( ( $sc_debug_mode =~ /yes/i ) && ( $sc_debug_track_cartid =~ /yes/i ) ) {

        if ( ( $cookie{'cart_id'} ) && ( $form_data{'cart_id'} ) ) {
            $cart_id = $form_data{'cart_id'};
            ( $cart_id, $junk ) = split( /\*/, $cart_id, 2 );
            if ( $cart_id ne $cookie{'cart_id'} ) {
                local ($mytext) = "Cart ID changed: cookie=$cookie{'cart_id'} ";
                $mytext .= "form=$form_data{'cart_id'}|";
                $mytext .= "form values:|";
                $mytext .= &debugGetFormKeysValues;
                update_error_log( $mytext, __FILE__, __LINE__ );
            }
        }
    }

    #codehook('alias_and_override_end');

}

#########################################################################
#                       Check for site page requests
#########################################################################
#
# check_for_site_page_requests is responsible for checking to
# make sure that only authorized pages (legacy feature) are viewable using
# this application. It takes no arguments and is called
# with the following syntax:
#
# &check_for_site_page_requests;
#
# The routine simply checks to make sure that if
# the page variable extension is not one that is defined
# in the setup file as an appropriate extension like .html
# or .htm, or there is no page being requestd (ie: the
# store front is being displayed) it will send a warning
# to the user, append the error log, and exit.
#
# @acceptable_file_extensions_to_display is an array of
# acceptable file extensions defined in the setup file.
# To be more or less restrictive, just modify this list.
#
# Specifically, for each extension defined in the setup
# file, if the value of the page variable coming in from
# the form ($page) is like the extension (/$file_extension/)
# or there is no value for page (eq ""), we will set
# $valid_extension equal to yes.
#
#########################################################################

sub check_for_site_page_requests {

    my $valid_extension = '';

    # error check this ... this is our safety net
    if ( ( $form_data{'page'} =~ /\.\.\/|http:|https:|ftp:/ ) || ( $form_data{'cartlink'} =~ /\.\.\/|http:|https:|ftp:/ ) ) {
        $form_data{'page'} = q{};
        $form_data{'cartlink'} = q{};
        PrintNoRemotePages();
        call_exit();
    }

    if ( $form_data{'page'} ) {

        # These expressions will strip of any path information so
        # files are only loaded from the appropriate directory.
        # We will also only load pages of the proper extension,
        # which is checked in below, but set in our setup files.
        $page = $form_data{'page'};
        $page =~ /([\w\-\=\+\/]+)\.(\w+)/;
        $page     = "$1.$2";
        $page_extension = ".$2";
        $page    = q{} if ( $page eq '.' );
        $page =~ s/^\/+//;    # Get rid of any residual / prefix

        foreach $file_extension (@acceptable_file_extensions_to_display) {
            if ( $page_extension eq $file_extension || $page eq '' ) {
                $valid_extension = 'yes';
            }
        }

        # Next, the script checks to see if $valid_extension has
        # been set to "yes".
        #
        # If the value for page satisfied any of the extensions
        # in @acceptable_file_extensions_to_display, the script
        # will set $valid_extension equal to yes. If the value
        # is set to yes, the subroutine will go on with it's work.
        # Otherwise it will exit with a warning and write to the
        # eror log if appropriate
        #
        # Notice that we pass three parameters to the
        # update_error_log subroutine which will be discussed
        # later. The subroutine gets a warning, the
        # name of the file, and the line number of the error.

        if ( $valid_extension ne 'yes' ) {
            if ( $sc_shall_i_log_static_HTML_errors !~ /no/i ) { # default is yes
                update_error_log( "$agora_error_logging_notice05", __FILE__, __LINE__ );
            }
            PrintInvalidPageExtension();
            call_exit();
        }

        $form_data{'page'} = $page;    # set it to the untainted & filtered one
    }

    # This is section added by Mister Ed 09/2002 and operates
    # exactly like the routines above for the pages parsed by
    # agoracart, but for the cartlinks instead.
    #
    if ( $form_data{'cartlink'} ) {

        $cartlink = $form_data{'cartlink'};
        $cartlink =~ /([\w\-\=\+\/]+)\.(\w+)/;
        $cartlink  = "$1.$2";
        $cartlink =~ s/^\/+//;
        $cartlink_extension = ".$2";
        $cartlink    = q{} if ( $cartlink eq '.' );
        $cartlink  =~ s/^\/+//;    # Get rid of any residual / prefix

        foreach $file_extension (@acceptable_file_extensions_to_display) {
            if ( $cartlink_extension eq $file_extension || $cartlink eq '' ) {
                $valid_extension = 'yes';
            }
        }

        if ( $valid_extension ne 'yes' ) {
            if ( $sc_shall_i_log_static_HTML_errors !~ /no/i ) { # default is yes
                update_error_log( "$agora_error_logging_notice05", __FILE__, __LINE__ );
            }
            PrintInvalidPageExtension();
            call_exit();
        }

        $form_data{'cartlink'} =  $cartlink;    # set it to the untainted & filtered one

    }

}

#########################################################################
#                       Output Frontpage
#########################################################################
#
# output_frontpage is used to display the frontpage of the
# store.  It takes no arguments and is accessed with the
# following syntax:
#
# output_frontpage();
#
# The subroutine simply utilizes the display_page
# subroutine which is discussed later to output the
# frontpage file, the location of which, is defined
# in agora_setup.pl.  display_page takes four arguments:
# the cart path, the routine calling it, the current
# filename and the current line number.
#
#########################################################################

sub output_frontpage {
    codehook('output_frontpage');

    require_supporting_libraries( __FILE__, __LINE__,  "$sc_delete_cart_time_keeper_path" );
    my $time = time();
    my $compareTime = $time - $sc_last_cart_delete_check;

    # clear out old carts & update file so we only expire carts every 8 hours.
    if ( $compareTime > $sc_period_for_cart_delete_check ) {
        my $contents = qq|\$sc_last_cart_delete_check = '$time';\n1;|;
        open( UPDATEFILE, ">./$sc_delete_cart_time_keeper_path" ) || my_die("Can't Open $sc_delete_cart_time_keeper_path");
        print( UPDATEFILE $contents );
        close(UPDATEFILE);

        check_cart_expiry();
        delete_old_carts();
    }

    display_page( "$sc_store_front_path", 'Output Frontpage',__FILE__, __LINE__ );
}

#########################################################################
#                     load_cart_copy Subroutine
#########################################################################

sub load_cart_copy {

    local ( @cart_fields, $temp );
    local ($kount) = 100;

    open( CART, "$sc_cart_path" ) || file_open_error( "$sc_cart_path", 'load_cart_contents', __FILE__,__LINE__ );

    while (<CART>) {
        chop;
        $temp = $_;
        $kount++;
        $cart_copy{$kount} = $temp;
    }
    close(CART);
    $sc_cart_copy_made = 'yes';
}

#########################################################################
#                     save_cart_copy Subroutine
#########################################################################

sub save_cart_copy {

    local ( @cart_fields, $cart_row_number, $temp, $inx );

    open( CART, ">$sc_cart_path" ) || file_open_error( "$sc_cart_path", 'save_cart_contents', __FILE__,__LINE__ );

    foreach $inx ( sort ( keys %cart_copy ) ) {
        $temp = $cart_copy{$inx};
        print CART $temp, "\n";
    }
    close(CART);
}

#########################################################################
#                    Virtual Fields Subroutines
#########################################################################
# These routines are independent of any particular database interface
#
# $VF_HOOK{'filename'} holds the default subroutine for vitual fields
# that do not use the standard one
# $VF_DEF{'filename'} holds the %hash name
# @RECORD is the set of fields for the current record
# $ID is the id number of the current record
#########################################################################

sub vf_get_data {
    local ( $VF_file, $fname, $ID, @RECORD ) = @_;
    local $field, $xans, @REC;
    @REC = @RECORD;    # alias
    return vf_eval($fname);
}


sub vf_eval {
    local ($fname) = @_;
    local $xcmd, $hname;

    # need to get the field itself from the field name
    $xcmd = '$field = $' . $VF_DEF{$VF_file} . '{"' . $fname . '"}';
    eval($xcmd);
    return vf_do_eval_work($field);
}

sub vf_do_eval_work {
    local ($field) = @_;
    local $ans, $result, $temp, $a1, $a2, $a3, $a4, $a5, $a6, $a7, $a8, $a9;
    $ans = q{};
    if ( $VF_HOOK{$VF_file} ) {
        eval( '&' . "$VF_HOOK{$VF_file};" );
    }
    else {
        if ( substr( $field, 0, 1 ) eq '*' ) {    # V-field
            eval( substr( $field, 1, 9999 ) );
            $err_code = $@;
            if ( $err_code ) {
                update_error_log( "V-field ${field}($VF_file) $sc_error_text01: $err_code",__FILE__, __LINE__ );
            }
        }
        else {    # D-field
            $ans = $RECORD[$field];
        }
    }
    return $ans;
}

#######################################################################
#                        Delete Old Carts
#######################################################################
# delete_old_carts is a subroutine which is used to prune
# the carts directory, cleaning out all the old carts
# after some time interval defined in the manager settings (aved in the user
# settings file).  It takes no arguments and is called with the following
# syntax:
#
# delete_old_carts();

sub check_cart_expiry {
    check_cart_type_file_expiry("$sc_cart_path");
    check_cart_type_file_expiry("$sc_verify_order_path");
    check_cart_type_file_expiry("$sc_server_cookie_path");
}

#############

sub check_cart_type_file_expiry {
    local ($cart_type_file_path) = @_;
    if ( -M "$cart_type_file_path" > $sc_number_days_keep_old_carts ) {
        if ( $cart_type_file_path =~ /cart/i ) {
            codehook('delete-cart');
            if (   ($sc_db_index_for_inventory)
                && ( $sc_inventory_subtract_at_add_to_cart =~ /yes/i ) )
            {
                open( CART, "$cart_type_file_path" )
                  || errorcode( __FILE__, __LINE__,
                    "$sc_cart_path", "$!", 'ignore', 'FILE OPEN ERROR', '0'
                  );
                while (<CART>) {
                    my @row = split( /\|/, $_ );
                    add_inventory( $row[1], $row[0] );
                }
                close(CART);
            }
        }
        else {
            codehook('delete-non-cart');
        }
        unlink("$cart_type_file_path");
    }
}

#############

sub delete_old_carts {

    # The subroutine begins by grabbing a listing of all of
    # the client created shoppping carts in the User_carts
    # directory.
    #
    # It then opens the directory and reads the contents using
    # grep to grab every file with the extension _cart. Then
    # it closes the directory.
    #
    # If the script has any trouble opening the directory,
    # it will output an error message using the
    # file_open_error subroutine discussed later.  To the
    # subroutine, it will pass the name of the file which had
    # trouble, as well as the current routine in the script
    # having trouble , the filename and the current line
    # number.

    opendir( USER_CARTS, "$sc_user_carts_directory_path" ) || file_open_error(
        "$sc_user_carts_directory_path", 'Delete Old Carts', __FILE__, __LINE__ );
    @carts = grep( /\.[0-9]/, readdir(USER_CARTS) );  # must have . followed by digits
    closedir(USER_CARTS);

    # Now, for every cart in the directory, delete the cart if
    # it is older than half a day.  The -M file test returns
    # the number of days since the file was last modified.
    # Since the result is in terms of days, if the value is
    # greater than the value of $sc_number_days_keep_old_carts
    # set in main manager settings, we'll delete the file.

    foreach $cart (@carts) {

        # code below deletes carts and other files in this directory that have expired
        $sc_cart_path = "$sc_user_carts_directory_path/$cart";
        $sc_cart_path =~ /([\w\-\=\+\/\.]+)/;
        $sc_cart_path = "$1";
        $sc_cart_path = q{} if ( $sc_cart_path eq '.' );
        $sc_cart_path =~ s/^\/+//;    # Get rid of any residual / prefix
        check_cart_type_file_expiry("$sc_cart_path");
    }

}

#########################################################################

1;
