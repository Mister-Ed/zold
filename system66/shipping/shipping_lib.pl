$versions{'shipping_lib.pl'} = '06.6.00.0001';

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
# Contains general shipping routines/functions. Individual shipment
# ratings are separated into separate files for USPS, UPS, FedEx, etc.
#
##### Modifications by Mister Ed at K-Factor Technologies, Inc / AgoraCart.com
#
# Modified by Mister Ed August 17, 2010- updated for version 6.0+
# Compatibility for LWP 6.0+ - Added by Mister Ed - March 15, 2011
# Move specific shipment ratings (UPS_legacy and USPS) out to separate libs - Mister Ed - August 2017
# Allow alternate shipment libs to be used from maketplace - by Mister Ed - August 2017
#

#######################################################################
#                    shipping_lib.pl setup
#######################################################################

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

# Do we need sockets part of this library ?
if ( ( $sc_use_SBW =~ /yes/i ) || ( $sc_need_sockets =~ /yes/i ) ) {
    if ( $sc_use_socket eq '' ) {    # should be set but if not ...
        $sc_use_socket = 'LWP';      # set our preferred default
    }

    if ( $sc_use_socket =~ /LWP/ ) {    #helpful (but not required) error check
        $test_result = eval("use LWP::Simple qw(!head); 1;");
        if ( $test_result ne '1' ) {
            print "Content-type: text/html\n\n";
            print "$agora_shiplib_message01.\n";
            if ( $main_program_running =~ /yes/i ) {
                call_exit();
            }
        }
    }
    #if ( $sc_use_socket =~ /http-lib/i ) {
    #    local ($wtd) = '';
    #    if ( $main_program_running =~ /yes/i ) {
    #        $wtd .= 'warn exit';
    #    }
    #    request_supporting_libraries( $wtd, __FILE__, __LINE__,
    #        "$sc_lib_dir/http-lib.pl" );
    #    $http_lib_loaded = 'yes';
    #}
}

#######################################################################
#                    agora_http_get
#######################################################################

sub agora_http_get {
    local ( $site, $path, $workString ) = @_;
    local ( $answer, $doworkString );

    if ( $sc_use_socket =~ /lwp/i ) {    # use LWP library GET
            # By calling this way, no error generated if library is missing
            # when the library is first loaded up or at runtime of this routine
        $doworkString = "http://$site$path\?${workString}";
        $answer       = eval("use LWP::Simple qw(!head); get\(\"$doworkString\"\);");
    }
    #if ( $sc_use_socket =~ /http-lib/i ) {    # use http-lib.pl library GET
    #    $answer = HTTPGet( $path, $site, 80, $workString );
    #}
    return $answer;
}

#######################################################################
#                    ship_put_in_boxes
#######################################################################
# This routine should take the string of weights and descriptions,
# and decide what goes in what box.  It also returns a string of
# shipping instructions so the people packing know what to put in
# each box to get the weight correct.
#
# It is not very efficient, nor is it very smart!
#

sub ship_put_in_boxes {
    my ( $weight_data, $names_data, $Origin_ZIP, $max_per_box ) = @_;
    my (
        $alt_origin, $instructions, $special_instructions,
        $items_in_box, $weight_of_box, $new_wt_data,
        $inx1, $inx2, $zip_list,
        $origin_product_list, $junk, $items_this_round,
        $value_of_box
    ) = q{};
    my ( $packageType, $separatePackage, $length, $width, $height, $girth,
        $alt_stateprov )
      = q{};
    my ($continue) = 'yes';
    my ( $ownbox, $single_item_box_list ) = '';
    $instructions         = q{};
    $special_instructions = q{};
    codehook( 'shippinglib-put-in-boxes-top' );
    if ( !( $continue =~ /yes/i ) ) { return; }
    if ( $Origin_ZIP eq '' ) { $Origin_ZIP = "$agora_shiplib_message04"; }
    $instructions = "$agora_shiplib_message02\n";
    $instructions .= "$agora_shiplib_message03: $Origin_ZIP\n\n";
    $instructions .= "$agora_shiplib_message05\n";
    $items_in_box  = 0;
    $weight_of_box = 0;
    $value_of_box  = 0;
    $new_wt_data   = q{};

# ship total already separate    ($junk,$weight_data) = split(/\|/,$weight_data,2);
    my @ship_list = split( /\|/, $weight_data );
    @name_list = split( /\|/, $names_data );

    #print("<br><br>Orignal Weight Data = $weight_data<br><br>");

    for ( $inx1 = 0 ; $inx1 <= $#ship_list ; $inx1++ ) {
        (
            $item_qty, $item_wt, $item_val, $alt_origin, $alt_stateprov,
            $ownbox, $junk
        ) = split( /\*/, $ship_list[$inx1], 6 );
        $ztitle           = $name_list[$inx1];
        $items_this_round = 0;
        for ( $inx2 = $item_qty ; $inx2 > 0 ; $inx2-- ) {
            ( $packageType, $separatePackage, $length, $width, $height, $girth )
              = '';
            ( $packageType, $separatePackage, $length, $width, $height, $girth )
              = split( /\,/, $ownbox );    ##split on comma
            if ( $separatePackage =~ /$sc_yes/ ) {
                if ( $single_item_box_list ) {
                    $single_item_box_list .= '|';
                }
                $single_item_box_list .=
"1*$item_wt*$item_val*$alt_origin*$alt_stateprov*$length*$width*$height*$girth*$packageType";

                #  $items_in_box = 1;
                #  $weight_of_box = $item_wt;
                #  $value_of_box = $item_val;
                $items_this_round++;
            }
            else {
                if ( $items_in_box == 0 ) {
                    $items_in_box  = 1;
                    $weight_of_box = $item_wt;
                    $value_of_box  = $item_val;
                    $items_this_round++;
                }
                else {    # add to or close/start box
                    if ( ( $weight_of_box + $item_wt ) < $max_per_box ) {   #add
                        $items_in_box++;
                        $weight_of_box = $weight_of_box + $item_wt;
                        $value_of_box  = $value_of_box + $item_val;
                        $items_this_round++;
                    }
                    else {    # close, then start a new box
                        if ( $items_this_round > 0 ) {
                            $instructions .=
                              "  $items_this_round $ztitle [$item_wt]\n";
                        }
                        $instructions .=
                          " $agora_shiplib_message06 $weight_of_box\n\n";
                        if ( $new_wt_data ne "" ) {
                            $new_wt_data .= '|';
                        }
                        $new_wt_data .= "1*${weight_of_box}*${value_of_box}*$alt_origin*$alt_stateprov*****";
                        $instructions .= "$agora_shiplib_message07\n";
                        $items_in_box     = 1;
                        $weight_of_box    = $item_wt;
                        $value_of_box     = $item_val;
                        $items_this_round = 1;
                    }    # end of: close, then start a new box
                }    # end of: else on add to or close/start box
            }    # end of: else on ... if $separatePackage
        }    # end of for statement: ($inx2=$item_qty; $inx2 > 0; $inx2--)

        if ( $items_this_round > 0 ) {
            $instructions .= "  $items_this_round $ztitle [$item_wt]\n";
        }
    }
    $instructions .= " $agora_shiplib_message06 $weight_of_box\n\n";

    if ( $single_item_box_list ) {
        if ( $new_wt_data ) {
            $new_wt_data .= '|';
        }
        $new_wt_data .= "$single_item_box_list";
        $single_item_box_list = '';
    }

# commented out to fix for extra boxes being added in
# by Mister Ed March 27, 2008
#    if ($new_wt_data ne "") {
#    	$new_wt_data .= '|';
#    }
#    $new_wt_data .= "1*${weight_of_box}*${value_of_box}*$alt_origin*$alt_stateprov*****";

    if ( ( ${weight_of_box} ne '0' ) && ( ${value_of_box} ne '0' ) ) {
        if ( $new_wt_data ) {
            $new_wt_data .= '|';
        }
        $new_wt_data .=
          "1*${weight_of_box}*${value_of_box}*$alt_origin*$alt_stateprov*****";
    }

    if ( $max_per_box == 0 ) {
        $instructions = "$agora_shiplib_message08";
    }

    $final_instructions = $special_instructions . $instructions;
    codehook('shippinglib-put-in-boxes-bot');

# debug
# print "<br><br> \$new_wt_data = $new_wt_data <br><br> $final_instructions = $final_instructions";
    return ( $new_wt_data, $final_instructions );
}

#######################################################################
#                    calc_SBW
#######################################################################

sub calc_SBW {
    my ( $method, $dest, $country, $shipping_total, $weight_data ) = @_;
    my ( $module_path, $via, $junk );

    ( $via, $junk ) = split( /\ /, $method, 2 );

    codehook( 'SBW_top' );

    # UPS XML is members only file
    if ( ( $via =~ /UPS/i ) && ( $sc_use_UPS =~ /yes/i ) ) {

        # modified by Mister Ed 10/24/2003
        $sc_verify_Origin_ZIP = $sc_UPS_Origin_ZIP;

        # Use XML, else use the legacy version.
        # XML is a subscription library
        if ( $sc_use_UPS_XMLrate eq 'yes' ) {
            $sc_verify_Origin_Country = $sc_UPS_Origin_Country;
            $module_path = "$sc_shiplib_dir/UPS_XMLrate_ship-lib.pl";
            if ( ( $sc_use_marketplace_UPS_shipping_module eq 'yes' ) && ( $sc_UPS_module_name ) ) {
                $module_path = "$sc_add_on_modules_dir/$sc_UPS_module_name"
            }
            require_supporting_libraries( __FILE__, __LINE__,
                "$module_path" );
            codehook( 'SBW_UPS_XML' );
            return calc_XMLups( $method, $sc_verify_Origin_ZIP,
                $sc_verify_Origin_Country, $dest, $country, $shipping_total,
                $weight_data );
        }
        else {
            # free / included library
            require_supporting_libraries( __FILE__, __LINE__,
                "$sc_shiplib_dir/UPS_legacy_ship-lib.pl" );
            return calc_ups( $method, $sc_verify_Origin_ZIP,
                $sc_verify_Origin_Country, $dest, $country, $shipping_total,
                $weight_data );
        }
    }

    # free/included library
    if ( ( $via =~ /USPS/i ) && ( $sc_use_USPS =~ /yes/i ) ) {
        $sc_verify_Origin_ZIP = $sc_USPS_Origin_ZIP;
        $module_path = "$sc_shiplib_dir/USPS_ship-lib.pl";
        if ( ( $sc_use_marketplace_USPS_shipping_module eq 'yes' ) && ( $sc_USPS_module_name ) ) {
            $module_path = "$sc_add_on_modules_dir/$sc_USPS_module_name"
        }
        require_supporting_libraries( __FILE__, __LINE__,
            "$module_path" );
        return calc_usps( $method, $sc_verify_Origin_ZIP, $dest, $country,
            $shipping_total, $weight_data );
    }

    # subscription library
    if ( ( $via =~ /FedEx/i ) && ( $sc_use_FedEx =~ /yes/i ) ) {
        $module_path = "$sc_shiplib_dir/FedEx_ship-lib.pl";
        if ( ( $sc_use_marketplace_FedEx_shipping_module eq 'yes' ) && ( $sc_FedEx_module_name ) ) {
            $module_path = "$sc_add_on_modules_dir/$sc_FedEx_module_name"
        }
        require_supporting_libraries( __FILE__, __LINE__,
            "$module_path" );
        my $stateprov = "$form_data{'Ecom_ShipTo_Postal_StateProv'}";
        if ( $stateprov eq '' ) {
            $stateprov = "$form_data{'Ecom_BillTo_Postal_StateProv'}"
              if $form_data{'Ecom_BillTo_Postal_StateProv'};
        }
        return calc_FedEx( $method, $dest, $stateprov, $country, $shipping_total,
            $weight_data );
    }

    # added by Mister Ed Jan 26 2005 for future expansion
    # subscription library
    if ( ( $via =~ /DHL/i ) && ( $sc_use_DHL =~ /yes/i ) ) {
        $module_path = "$sc_shiplib_dir/DHL_ship-lib.pl";
        if ( ( $sc_use_marketplace_DHL_shipping_module eq 'yes' ) && ( $sc_DHL_module_path ) ) {
            $module_path = "$sc_add_on_modules_dir/$sc_DHL_module_path"
        }
        require_supporting_libraries( __FILE__, __LINE__,
            "$sc_admin_dir/agora_ship_DHL_user_lib.pl" );
        $sc_verify_Origin_Country = $sc_DHL_Origin_Country;
        $sc_verify_Origin_ZIP     = $sc_DHL_Origin_ZIP;
        require_supporting_libraries( __FILE__, __LINE__,
            "$module_path" );
        return calc_DHL( $method, $sc_verify_Origin_ZIP,
            $sc_verify_Origin_Country, $dest, $country, $shipping_total,
            $weight_data );
    }

    codehook( 'SBW_bot' );

    # got here, this is bad, return zero value
    return 0;

}

#######################################################################
#                    custom_shipping_insurance
#######################################################################
#
# Used for manual shipping insurance intervention
# this subroutine not used currently, must use codehooks
#

sub custom_shipping_insurance {

    my $insurance = "$form_data{'Ecom_ShipTo_Insurance'}";    #Get client's answer for insurance YES or NO

    $insurancecost = 0;            #Default value of insurance charge
    $subtotalins   = $subtotal;    #Change variable name for insurance value

    if ( $insurance =~ /yes/i )
    {    #This logic will only be executed if client said YES
        codehook( 'custom_shipping_insurance_cost' );
    }
    else {
        $insurancecost =  0;    #Reset to zero, just in case something happened during logic
    }

    #   print "<b>Insurance Cost: $insurancecost USD</b>";
    return ( $insurancecost, $uspshandling );

}

#######################################################################
#                    define_shipping_logic
#######################################################################

sub define_shipping_logic {

# original stevo passed here.  w/ alt origination if enabled. split off shipping total
# altered by Mister Ed @ AgoraCart.com Jan 2005
    local ( $shipping_total, $stevo_shipping_thing ) = @_;
    local ( $orig_zip, $dest_zip, $ship_method, $mylogic );
    local ($shipping_price) = 0;
    local ( $ship_logic_run, $ship_logic_done ) = 'no';
    local ($continue)  = 'yes';
    local ($use_eform) = 'no';
    my ($SBW_shipping_price) = 0;
    $sc_custom_logic_run_for_shipping = '';

    codehook( 'shippinglib-define-shipping-logic' );
    if ( !( $continue =~ /yes/i ) ) { return; }

    $ship_method = $form_data{'Ecom_ShipTo_Method'};
    if ( $ship_method eq '' ) {    # try eform, perhaps there is a value there
        $use_eform   = 'yes';
        $ship_method = $eform{'Ecom_ShipTo_Method'};
    }
    ( $sc_ship_method_shortname, $junk ) = split( /\(/, $ship_method, 2 );

    if (   ( $sc_use_custom_shipping_logic =~ /yes/i )
        && ( $sc_location_custom_shipping_logic =~ /before/i ) )
    {
        $mylogic = "$sc_custom_shipping_logic";
        eval($mylogic);
        $err_code = $@;
        if ( $err_code ) {    #script died, error of some kind
            update_error_log( "custom-shipping-logic $err_code ", '', '' );
        }
        $ship_logic_run = 'yes';
        if (   ( $ship_logic_done =~ /yes/i )
            || ( $shipping_logic_done =~ /yes/i ) )
        {   #done, may exit
            return $shipping_price;
        }
    }

    # print "\$shipping_total: $shipping_total<br>\n";
    # print "\$stevo_shipping_thing: $stevo_shipping_thing<br>\n";
    if ( $sc_use_SBW =~ /yes/i ) {

        # April 2019 - Added to fix for real-time libs if viewing cart contents
        if ( $form_data{'dc'} || $form_data{'display_cart'} ||  $form_data{'submit_deletion_button.x'} || $form_data{'submit_change_quantity_button.x'} ) {
            require_supporting_libraries( __FILE__, __LINE__, "$sc_checkout_lib_dir/iso.pl" );
        }

        #  $stevo_shipping_thing = "$shipping_total$stevo_shipping_thing";
        $stevo_shipping_thing =~ s/\|//;

        # debug origination
        # print "stevo SBW yes location: $stevo_shipping_thing\n\n";

        $dest_zip     = $form_data{'Ecom_ShipTo_Postal_PostalCode'};
        $dest_country = $form_data{'Ecom_ShipTo_Postal_CountryCode'};
        if ( ( $dest_zip eq '' ) && ( $form_data{'Ecom_BillTo_Postal_PostalCode'} ) ) {    # try BillTo, perhaps there is a value there
            $dest_zip  = $form_data{'Ecom_BillTo_Postal_PostalCode'};
        }
        if ( $dest_zip eq '' ) {    # try eform, perhaps there is a value there
            $use_eform = 'yes';
            $dest_zip  = $eform{'Ecom_ShipTo_Postal_PostalCode'};
        }
        if ( ( $dest_country eq '' ) && ( $form_data{'Ecom_BillTo_Postal_CountryCode'} ) ) {    # try BillTo, perhaps there is a value there
            $dest_country  = $form_data{'Ecom_BillTo_Postal_CountryCode'};
        }
        if ( $dest_country eq '' ) { # try eform, perhaps there is a value there
            $use_eform    = 'yes';
            $dest_country = $eform{'Ecom_ShipTo_Postal_CountryCode'};
        }
        if ( $dest_country eq '' ) { # try eform, perhaps there is a value there
            $use_eform    = 'yes';
            $dest_country = $eform{'Ecom_BillTo_Postal_CountryCode'};
        }
        if ( $dest_country eq '' ) {    # USA as last resort
            $dest_country = 'US';
        }
        $SBW_shipping_price =
          calc_SBW( $ship_method, $dest_zip, $dest_country, $shipping_total,
            $stevo_shipping_thing );
        $shipping_price = $shipping_price + $SBW_shipping_price;
        $ship_logic_run = 'yes';
    }

    if ( ( $sc_use_custom_shipping_logic =~ /yes/i )
        && ( $sc_location_custom_shipping_logic =~ /after/i ) )
    {
        $mylogic = "$sc_custom_shipping_logic";
        my $temp_shipping_price_holder = $shipping_price;
        eval($mylogic);
        $err_code = $@;
        if ( $err_code ) {    #script died, error of some kind
            update_error_log( "custom-shipping-logic $err_code ", '', '' );
        } elsif ( $sc_custom_logic_run_for_shipping eq 'yes' && $sc_custom_logic_calculated_successfully eq '' ) {
            $sc_custom_logic_calculated_successfully = 1;
        }
        $ship_logic_run = 'yes';
        if ( !($sc_custom_logic_calculated_successfully) && ( $shipping_price == 0 ) ) {
            $shipping_price = $temp_shipping_price_holder;
        }
        if (   ( $ship_logic_done =~ /yes/i )
            || ( $shipping_logic_done =~ /yes/i ) )
        {    #done, may exit
            return $shipping_price;
        }
    }

    if ( !( $ship_logic_run =~ /yes/i ) ) {    # this is what is left
        $shipping_price = $shipping_total;
    }

    if (   ( $shipping_price > 0 )
        || ( $sc_add_handling_cost_if_shipping_is_zero =~ /yes/i ) )
    {
        if ( $sc_handling_charge_type =~ /percentage/i ) {
            $shipping_price =
              $shipping_price + ( $temp_total * $sc_handling_charge );
        }
        elsif ( $sc_handling_charge_type =~ /flat/i ) {
            $shipping_price = $shipping_price + $sc_handling_charge;
        }
        else {
            # do nothing
        }
    }

    return format_price($shipping_price);

}

#######################################################################
#                    LWP_post
#######################################################################

sub LWP_post {

    # The $ua is created once when the application starts up.  New request
    # objects should normally created for each request sent.

    local ($ua);
    local ($stuff) = @_;
    local ( $site_url, $info_to_post );
    ( $site_url, $info_to_post ) = split( /\?/, $stuff, 2 );

    # Create a user agent object
    $ua = new LWP::UserAgent;
    $ua->agent( 'AgentName/0.1 ' . $ua->agent );

    # Create a request
    my $req = new HTTP::Request POST => $site_url;
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($info_to_post);

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    # Check the outcome of the response
    if ( $res->is_success ) {
        return $res->content;
    }
    else {
        return $sc_ERROR_text01;
    }
}

#######################################################################

$shipping_lib_loaded_ok = "yes";

1;
