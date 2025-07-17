$versions{'order_processing.pl'} = '06.6.00.0001';

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


require_supporting_libraries( __FILE__, __LINE__, "$sc_checkout_lib_dir/iso.pl" );
$mustbegreaterthanthis = .0001;

########################################################################
#                  process_order_form Subroutine
########################################################################
#
# subroutine: process_order_form
#   Usage:
#     process_order_form();
#
#   Parameters:
#     None. This takes input from the form
#     variables of the previously displayed
#     order form
#
#   Output:
#     The HTML for displaying the shipping, discount,
#     and sales tax calculations for the cart.
#
########################################################################

sub process_order_form {

    local ( $subtotal, $total_quantity, $total_measured_quantity, $required_fields_filled_in, $taxable_grand_total ) = q{};
    local ($hidden_fields) = make_hidden_fields();
    local ($continue) = 1;
    local $we_need_to_exit = 0;
    local $skip_cart_contents_table = '';

    # make sure order form fields are populated
    if ( ( $form_data{'gateway'} ) && ( $form_data{'submit_order_form_button'} ) ) {
        gateway_form_field_check();
    }

    codehook( 'process_order_form_top' );

    if ( $continue == 0 ) { return; }

    # First, we output the header of the processing of the order

    print qq~$sc_doctype
<html>
<head>
<title>$agora_checkout_two</title>
$sc_standard_head_info
$sc_noindex_robot_meta_tags
</head>
<body>
~;

    # We display the cart table or skip it if disabled.
    if ( $skip_cart_contents_table && $sc_donation_mode eq 'yes' ) {
        (
            $taxable_grand_total, $subtotal, $total_quantity,
            $total_measured_quantity, $stevo_shipping_thing
        ) = dont_display_cart_table('verify');
    }
    else {
        (
            $taxable_grand_total, $subtotal, $total_quantity,
            $total_measured_quantity, $stevo_shipping_thing
        ) = display_cart_table('verify');
    }

    # Now that we have the text of the cart
    # all together. We check the required
    # form fields from the previous form
    # to see if they were filled in by the user
    #
    # $required_fields_filled_in is set to "yes"
    # and remains this way until any ONE
    # required field is missing -- at which
    # point it is set to no.

    $required_fields_filled_in = 'yes';

    codehook( 'set_form_required_fields' );

    # checks for prevent of Zero sub total orders.  Set in main settings manager
    if ( $sc_prevent_zero_total_orders =~ /yes/i ) {
        if ( $subtotal < $mustbegreaterthanthis ) {
            $we_need_to_exit++;
            if ( $we_need_to_exit eq 1 ) {
                print $sc_template_full_width_div_container_definition;
            }
            $sc_error_p_tags =~ s/\[\[errormessage\]\]/$agora_empty_orders/;
            print $sc_error_p_tags;
        }
    }

    # checks for minimum order amount.  Set in main settings manager
    if ( $subtotal < $sc_minimum_order_amount ) {
        $we_need_to_exit++;

        if ( $we_need_to_exit eq 1 ) {
            print $sc_template_full_width_div_container_definition;
        }
        $sc_error_p_tags =~ s/\[\[errormessage\]\]/$agora_minimum_order $sc_minimum_order_amount $sc_minimum_order_text/;
        print $sc_error_p_tags;
    }

    foreach $required_field (@sc_order_form_required_fields) {
        if ( $form_data{$required_field} eq '' ) {
            $required_fields_filled_in = 'no';

            $we_need_to_exit++;
            if ( $we_need_to_exit eq 1 ) {
                print $sc_template_full_width_div_container_definition;
            }
            $sc_error_p_tags =~ s/\[\[errormessage\]\]/$agora_missing_field $sc_order_form_array{$required_field}/;
            print $sc_error_p_tags;
        }

    }
    # End of checking required fields

    if ( $we_need_to_exit > 0 ) {
        print '</div>';
        $sc_order_form_make_changes =~ s/\[\[hiddenfields\]\]/$hidden_fields/;
        $sc_order_form_make_changes =~ s/\[\[hcode\]\]/$sc_pass_used_to_scramble/;
        $sc_order_form_make_changes =~ s/\[\[gateway\]\]/$form_data{'gateway'}/g;
        $sc_order_form_make_changes =~ s/\[\[formdataproduct\]\]/$form_data{'product'}/;
        print $sc_order_form_make_changes;
        CheckoutStoreFooter();
        call_exit();
    }

## Start of CC validation if appropriate
    if ( ( $sc_paid_by_ccard =~ /yes/i ) && ( $sc_CC_validation =~ /yes/i ) ) {

        require_supporting_libraries( __FILE__, __LINE__,"$sc_checkout_lib_dir/credit_card_validation_lib.pl" );

        $CC_exp_date =
            $form_data{'Ecom_Payment_Card_ExpDate_Month'} . '/'
          . $form_data{'Ecom_Payment_Card_ExpDate_Day'} . '/'
          . $form_data{'Ecom_Payment_Card_ExpDate_Year'};

        ( $error_code, $error_message ) =
          validate_credit_card_information(
            $form_data{'Ecom_Payment_Card_Type'},
            $form_data{'Ecom_Payment_Card_Number'}, $CC_exp_date );

        if ( $error_code != 0 ) {
            $required_fields_filled_in = 'no';
            $order_error_do_not_finish = 'yes';
            $sc_error_message_html =~ s/\[\[errormessage\]\]/$error_message/;
            print $sc_error_message_html;
        }

    }
## End of CC validation

    # generic way to set errors in various places like shipping lib
    if ( $order_error_do_not_finish =~ /yes/i ) {
        $sc_order_form_make_changes =~ s/\[\[hiddenfields\]\]/$hidden_fields/;
        $sc_order_form_make_changes =~ s/\[\[hcode\]\]/$sc_pass_used_to_scramble/;
        $sc_order_form_make_changes =~ s/\[\[gateway\]\]/$form_data{'gateway'}/g;
        $sc_order_form_make_changes =~ s/\[\[formdataproduct\]\]/$form_data{'product'}/;
        print $sc_order_form_make_changes;
        CheckoutStoreFooter();
        call_exit();
    }

    # Since the required fields were filled in correctly, we process the rest of the order

    if ( $required_fields_filled_in eq 'yes' ) {

        codehook('printSubmitPage');

    }
    else {
        # The user is notified if the order was not a success (not all required fields were filled in).
        $sc_error_message_html =~ s/\[\[errormessage\]\]/$messages{'ordprc_01'}/;
        print $sc_error_message_html;
    }

    CheckoutStoreFooter();

}

########################################################################
#                  set_order_form_array Subroutine
########################################################################
#
# expanded to cover all possible fields logged at order creation and
# most likely to be on a semi-normal order form

sub set_order_form_array {
    %sc_order_form_array = (
        'Ecom_BillTo_Postal_Name_First',"$order_form_array_BillTo_Postal_Name_First",
        'Ecom_BillTo_Postal_Name_Last',"$order_form_array_BillTo_Postal_Name_Last",
        'Ecom_BillTo_Postal_Street_Line1',"$order_form_array_BillTo_Postal_Street_Line1",
        'Ecom_BillTo_Postal_City', "$order_form_array_BillTo_Postal_City",
        'Ecom_BillTo_Postal_StateProv',"$order_form_array_BillTo_Postal_StateProv",
        'Ecom_BillTo_Postal_PostalCode', "$order_form_array_BillTo_PostalCode",
        'Ecom_BillTo_Postal_CountryCode',"$order_form_array_BillTo_Postal_CountryCode",
        'Ecom_ShipTo_Postal_Street_Line1',"$order_form_array_ShipTo_Postal_Street_Line1",
        'Ecom_ShipTo_Postal_City', "$order_form_array_ShipTo_Postal_City",
        'Ecom_ShipTo_Postal_StateProv',"$order_form_array_ShipTo_Postal_StateProv",
        'Ecom_ShipTo_Postal_PostalCode',"$order_form_array_ShipTo_Postal_PostalCode",
        'Ecom_ShipTo_Postal_CountryCode',"$order_form_array_ShipTo_Postal_CountryCode",
        'Ecom_ShipTo_Method',"$order_form_array_ShipTo_Method",
        'Ecom_BillTo_Telecom_Phone_Number',"$order_form_array_BillTo_Telecom_Phone_Number",
        'Ecom_BillTo_Online_Email', "$order_form_array_BillTo_Online_Email",
        'Ecom_is_Residential',      "$order_form_array_is_Residential",
        'Ecom_ShipTo_Insurance',    "$order_form_array_ShipTo_Insurance",
        'Ecom_tos',                 "$order_form_array_tos",
        'Ecom_Payment_Card_Type',   "$order_form_array_Payment_Card_Type",
        'Ecom_Payment_Card_Number', "$order_form_array_Payment_Card_Number",
        'Ecom_Payment_Card_ExpDate_Month',"$order_form_array_Payment_Card_ExpDate_Month",
        'Ecom_Payment_Card_ExpDate_Day',"$order_form_array_Payment_Card_ExpDate_Day",
        'Ecom_Payment_Card_ExpDate_Year',"$order_form_array_Payment_Card_ExpDate_Year",
        'Ecom_BillTo_Company_Name',"$order_form_array_BillTo_Company_Name",
        'Ecom_ShipTo_Company_Name',   "$order_form_array_ShipTo_Company_Name",
        'Ecom_BillTo_Fax_Number',     "$order_form_array_BillTo_Fax_Number",
        'Ecom_form_User1',            "$order_form_array_form_User1",
        'Ecom_form_User2',            "$order_form_array_form_User2",
        'Ecom_form_User3',            "$order_form_array_form_User3",
        'Ecom_form_User4',            "$order_form_array_form_User4",
        'Ecom_form_User5',            "$order_form_array_form_User5",
        'Ecom_form_User6',            "$order_form_array_form_User6",
        'Ecom_form_User7',            "$order_form_array_form_User7",
        'Ecom_form_User8',            "$order_form_array_form_User8",
        'Ecom_form_User9',            "$order_form_array_form_User9",
        'Ecom_form_User10',           "$order_form_array_form_User10",
        'Ecom_customer_order_notes1', "$order_form_array_customer_order_notes1",
        'Ecom_customer_order_notes2', "$order_form_array_customer_order_notes2",
        'Ecom_customer_order_notes3', "$order_form_array_customer_order_notes3",
        'Ecom_sales_rep',             "$order_form_array_sales_rep",
        'Ecom_how_did_you_find_us',   "$order_form_array_how_did_you_find_us",
        'Ecom_account_number',        "$order_form_array_account_number",
        'Ecom_preferrred_shipping_date',"$order_form_array_preferrred_shipping_date",
        'Ecom_ship_order_items_as_available',"$order_form_array_ship_order_items_as_available",
        'Ecom_GiftCard_number',      "$order_form_array_GiftCard_number",
        'Ecom_GiftCard_amount_used', "$order_form_array_GiftCard_amount_used",
        'Ecom_trade_in_allowance',   "$order_form_array_trade_in_allowance",
        'Ecom_rma_number',           "$order_form_array_rma_number"
    );

    codehook( 'set_order_form_array' );
}

########################################################################
#                  populate_orderlogging_hash Subroutine
########################################################################
#
# called in each gateway prior actual logging that is default for each specific gateway
# any overrides can be done at codehook at bottom of this subroutine or
# at any codehook towards the bottom of each gateway specific order process sub-routine

sub populate_orderlogging_hash {
    $orderLoggingHash{'tax1'} = format_price($sc_verify_etax1);
    $orderLoggingHash{'tax2'} = format_price($sc_verify_etax2);
    $orderLoggingHash{'tax3'} = format_price($sc_verify_etax3);
    if ( ( $sc_buySafe_is_enabled =~ /$sc_yes/ ) && ( $sc_verify_buySafe > 0 ) ) {
        $orderLoggingHash{'buySafe'} = format_price($sc_verify_buySafe);
    }
    if ( $sc_verify_discount ) {
        $orderLoggingHash{'discounts'} = format_price($sc_verify_discount);
    }
    if ( ( $eform_affiliate ) || ( $sc_affiliate_image_call ) ) {
        $orderLoggingHash{'affiliateTotal'} = $sc_verify_subtotal - $sc_verify_discount;
    }
    $orderLoggingHash{'salesTax'} = format_price($sc_verify_tax);
    $orderLoggingHash{'shippingTotal'} = format_price($sc_verify_shipping);
    $orderLoggingHash{'subTotal'}   = format_price($sc_verify_subtotal);
    $orderLoggingHash{'orderTotal'} = format_price($sc_verify_grand_total);
    # billing info
    $eform_Ecom_BillTo_Postal_Name_First =~ s/\s+$//i; # Remove any trailing space
    $eform_Ecom_BillTo_Postal_Name_Last =~ s/^\s+//i; # Remove any leading space
    if ( ( $eform_Ecom_BillTo_Postal_Name_First eq uc($eform_Ecom_BillTo_Postal_Name_First) ) || ( $eform_Ecom_BillTo_Postal_Name_First eq lc($eform_Ecom_BillTo_Postal_Name_First) ) ) { # check for all upper or all lower case entry
        $orderLoggingHash{'firstName'} = lc("$eform_Ecom_BillTo_Postal_Name_First");
        $orderLoggingHash{'firstName'} =~ s/\b(\w+)\b/ucfirst($1)/ge;
    } else { # if entry already has both upper and lower case leave it alone
        $orderLoggingHash{'firstName'} = "$eform_Ecom_BillTo_Postal_Name_First";
    }
if ( ( $eform_Ecom_BillTo_Postal_Name_Last eq uc($eform_Ecom_BillTo_Postal_Name_Last) ) || ( $eform_Ecom_BillTo_Postal_Name_Last eq lc($eform_Ecom_BillTo_Postal_Name_Last) ) ) { # check for all upper or all lower case entry
        $orderLoggingHash{'lastName'}  = lc("$eform_Ecom_BillTo_Postal_Name_Last");
        $        $orderLoggingHash{'lastName'} =~ s/\b(\w+)\b/ucfirst($1)/ge;
        $orderLoggingHash{'lastName'} =~ s/^Mc([a-z])/Mc\u\L$1/g;
        $orderLoggingHash{'lastName'} =~ s/^Mac([^aeiou])/Mac\u\L$1/g
    } else { # if entry already has both upper and lower case leave it alone
        $orderLoggingHash{'lastName'}  = "$eform_Ecom_BillTo_Postal_Name_Last";
    }
    $orderLoggingHash{'fullName'} = "$orderLoggingHash{'firstName'} $orderLoggingHash{'lastName'}";
    $orderLoggingHash{'orderFromAddress'} = "$eform_Ecom_BillTo_Postal_Street_Line1";
    $orderLoggingHash{'customerAddress2'} = "$eform_Ecom_BillTo_Postal_Street_Line2";
    $orderLoggingHash{'customerAddress3'} = "$eform_Ecom_BillTo_Postal_Street_Line3";
    $orderLoggingHash{'orderFromCity'}  = "$eform_Ecom_BillTo_Postal_City";
    $orderLoggingHash{'orderFromState'} = "$eform_Ecom_BillTo_Postal_StateProv";
    $orderLoggingHash{'orderFromPostal'} = "$eform_Ecom_BillTo_Postal_PostalCode";
    $orderLoggingHash{'orderFromCountry'} = "$eform_Ecom_BillTo_Postal_CountryCode";
    $orderLoggingHash{'customerPhone'} = "$eform_Ecom_BillTo_Telecom_Phone_Number";
    $orderLoggingHash{'faxNumber'}    = "$eform_Ecom_BillTo_Fax_Number";
    $orderLoggingHash{'companyName'}  = "$eform_Ecom_BillTo_Company_Name";
    $orderLoggingHash{'emailAddress'} = "$eform_Ecom_BillTo_Online_Email";
    # shipping info
    $eform_Ecom_ShipTo_Postal_Name_First =~ s/\s+$//i; # Remove any trailing space
    $eform_Ecom_ShipTo_Postal_Name_Last =~ s/^\s+//i; # Remove any leading space
    if ( ( $eform_Ecom_ShipTo_Postal_Name_First eq uc($eform_Ecom_ShipTo_Postal_Name_First) ) || ( $eform_Ecom_ShipTo_Postal_Name_First eq lc($eform_Ecom_ShipTo_Postal_Name_First) ) ) { # check for all upper or all lower case entry
        $eform_Ecom_ShipTo_Postal_Name_First = lc("$eform_Ecom_ShipTo_Postal_Name_First");
        $eform_Ecom_ShipTo_Postal_Name_First =~ s/\b(\w+)\b/ucfirst($1)/ge;
    }
    if ( ( $eform_Ecom_ShipTo_Postal_Name_Last eq uc($eform_Ecom_ShipTo_Postal_Name_Last) ) || ( $eform_Ecom_ShipTo_Postal_Name_Last eq lc($eform_Ecom_ShipTo_Postal_Name_Last) ) ) { # check for all upper or all lower case entry
        $eform_Ecom_ShipTo_Postal_Name_Last  = lc("$eform_Ecom_ShipTo_Postal_Name_Last");
        $eform_Ecom_ShipTo_Postal_Name_Last =~ s/\b(\w+)\b/ucfirst($1)/ge;
        $eform_Ecom_ShipTo_Postal_Name_Last =~ s/^Mc([a-z])/Mc\u\L$1/g;
        $eform_Ecom_ShipTo_Postal_Name_Last =~ s/^Mac([^aeiou])/Mac\u\L$1/g
    }
    $orderLoggingHash{'shipToName'} = "$eform_Ecom_ShipTo_Postal_Name_First $eform_Ecom_ShipTo_Postal_Name_Last";
    $orderLoggingHash{'shipToCompany'} = "$eform_Ecom_ShipTo_Company_Name";    #added July 2010
    $orderLoggingHash{'shipToAddress'} = "$eform_Ecom_ShipTo_Postal_Street_Line1";
    $orderLoggingHash{'shipToAddress2'} = "$eform_Ecom_ShipTo_Postal_Street_Line2";
    $orderLoggingHash{'shipToAddress3'} = "$eform_Ecom_ShipTo_Postal_Street_Line3";
    $orderLoggingHash{'shipToCity'}   = "$eform_Ecom_ShipTo_Postal_City";
    $orderLoggingHash{'shipToState'}  = "$eform_Ecom_ShipTo_Postal_StateProv";
    $orderLoggingHash{'shipToPostal'} = "$eform_Ecom_ShipTo_Postal_PostalCode";
    $orderLoggingHash{'shipToCountry'} = "$eform_Ecom_ShipTo_Postal_CountryCode";
    $orderLoggingHash{'shiptoResidential'} = $eform_Ecom_is_Residential;
    $orderLoggingHash{'shipMethod'} = $eform_Ecom_ShipTo_Method;
    $orderLoggingHash{'insureShipment'} = $eform_Ecom_ShipTo_Insurance;    # not implemented yet, for the future
    # cart specific info from order forms - optional mostly
    $orderLoggingHash{'orderStatus'}    = "$sc_order_status_default";
    $orderLoggingHash{'user1'}          = "$eform_Ecom_form_User1";
    $orderLoggingHash{'user2'}          = "$eform_Ecom_form_User2";
    $orderLoggingHash{'user3'}          = "$eform_Ecom_form_User3";
    $orderLoggingHash{'user4'}          = "$eform_Ecom_form_User4";
    $orderLoggingHash{'user5'}          = "$eform_Ecom_form_User5";
    $orderLoggingHash{'shiptrackingID'} = "$eform_Ecom_shiptrackingID";
    $orderLoggingHash{'netProfit'}      = q{};
    $orderLoggingHash{'affiliateID'}    = "$eform_affiliate";
    $orderLoggingHash{'affiliateMisc'}  = "$eform_Ecom_affiliateMisc";
    $orderLoggingHash{'termsOfService'} = "$eform_Ecom_tos";
    $orderLoggingHash{'member'}       = "$eform_member";     #added July 2010
    $orderLoggingHash{'pricingLevel'} = "$eform_pricing";    #added July 2010
    # new logging items added August 4, 2007 by Mister Ed
    $orderLoggingHash{'discountCode'} = "$eform_Ecom_Discount";
    $orderLoggingHash{'user6'}        = "$eform_Ecom_form_User6";
    $orderLoggingHash{'user7'}        = "$eform_Ecom_form_User7";
    $orderLoggingHash{'user8'}        = "$eform_Ecom_form_User8";
    $orderLoggingHash{'user9'}        = "$eform_Ecom_form_User9";
    $orderLoggingHash{'user10'}       = "$eform_Ecom_form_User10";
    $orderLoggingHash{'order_payment_status'} = "$eform_Ecom_order_payment_status";
    $orderLoggingHash{'order_payment_type_user1'} = "$eform_Ecom_order_payment_type_user1";
    $orderLoggingHash{'GiftCard_number'} = "$eform_Ecom_GiftCard_number";
    $orderLoggingHash{'GiftCard_amount_used'} = "$eform_Ecom_GiftCard_amount_used";
    $orderLoggingHash{'internal_company_notes1'} = "$eform_Ecom_internal_company_notes1";
    $orderLoggingHash{'internal_company_notes2'} = "$eform_Ecom_internal_company_notes2";
    $orderLoggingHash{'internal_company_notes3'} = "$eform_Ecom_internal_company_notes3";
    $orderLoggingHash{'customer_order_notes1'} = "$eform_Ecom_customer_order_notes1";
    $orderLoggingHash{'customer_order_notes2'} = "$eform_Ecom_customer_order_notes2";
    $orderLoggingHash{'customer_order_notes3'} = "$eform_Ecom_customer_order_notes3";
    $orderLoggingHash{'customer_order_notesDLtext'} = "$eform_Ecom_customer_order_notesDLtext";
    $orderLoggingHash{'customer_order_notesDLhtml'} = "$eform_Ecom_customer_order_notesDLhtml";
    $orderLoggingHash{'mailinglist_subscribe'} = "$eform_Ecom_mailinglist_subscribe";
    $orderLoggingHash{'wishlist_subscribe'} = "$eform_Ecom_wishlist_subscribe";
    $orderLoggingHash{'insurance_cost'}     = "$eform_Ecom_insurance_cost";
    $orderLoggingHash{'trade_in_allowance'} = "$eform_Ecom_trade_in_allowance";
    $orderLoggingHash{'rma_number'}         = "$eform_Ecom_rma_number";
    $orderLoggingHash{'customer_contact_notes1'} = "$eform_Ecom_customer_contact_notes1";
    $orderLoggingHash{'customer_contact_notes2'} = "$eform_Ecom_customer_contact_notes2";
    $orderLoggingHash{'account_number'}   = "$eform_Ecom_account_number";
    $orderLoggingHash{'sales_rep'}        = "$eform_Ecom_sales_rep";
    $orderLoggingHash{'sales_rep_notes1'} = "$eform_Ecom_sales_rep_notes1";
    $orderLoggingHash{'sales_rep_notes2'} = "$eform_Ecom_sales_rep_notes2";
    $orderLoggingHash{'how_did_you_find_us'} = "$eform_Ecom_how_did_you_find_us";
    $orderLoggingHash{'suggestion_box'} = "$eform_Ecom_suggestion_box";
    $orderLoggingHash{'preferrred_shipping_date'} = "$eform_Ecom_preferrred_shipping_date";
    $orderLoggingHash{'ship_order_items_as_available'} = "$eform_Ecom_ship_order_items_as_available";

    #change things here prior to gateway specific hash data changes
    codehook('populate_orderlogging_hash_bottom');
}

########################################################################
#                  log_order Subroutine
########################################################################

sub log_order {
    local ( $invoice, $customer_id ) = @_;
    local ( $filename, $filename7, $filename6, $filename5 ) = q{};
    local ( $filename2, $filename3, $filename4, $overview_string,
        $cart_lines_for_logging, $orderLogString, $orderLogStringShort ) = q{};
    local (@productlog, @keys) = q{};
    local (%productsSold);
    local ( $day, $month, $year ) = get_month_year();

    $customer_id =~ /([\w\-\=\+\/]+)\.(\w+)/;
    $customer_id = "$1.$2";
    $invoice =~ /(\w+)/;
    $invoice = "$1";
    $filename2 = "$sc_order_log_directory_path/$year/";
    $filename3 = "$sc_order_log_directory_path/$year/$month/";
    $filename7 = "$sc_order_log_directory_path/$year" . '_productSalesLog.prd2';

    if ( ( $sc_write_product_sales_logs =~ /yes/i ) && ( -e $filename7 ) ) {
        open( PRODLOG, $filename7 );
        @productlog = <PRODLOG>;
        close(PRODLOG);
        foreach $productlog (@productlog) {
            chomp($productlog);
            my ( $productName, $qty ) = split( "\t", $productlog );
            $productsSold{$productName} = $qty;
        }
    }

    if (   ( $sc_write_individual_order_logs =~ /yes/i ) || ( $sc_write_monthly_master_order_logs =~ /yes/i ) )  {
        get_file_lock("$sc_cart_path.lockfile");
        open( CART, "$sc_cart_path" ) || file_open_error( "$sc_cart_path", 'display_cart_contents', __FILE__, __LINE__ );

        while (<CART>) {
            if ( $cart_lines_for_logging ) {
                $cart_lines_for_logging .= '::'; # delimit cart contents for each item in cart if more than one item
            }
            my @cart_fields2      = split( /\|/, $_ );
            my $quantity          = $cart_fields2[0];
            my $pid               = $cart_fields2[1];
            my $category          = $cart_fields2[2];
            my $price             = $cart_fields2[3];
            my $product           = $cart_fields2[4];
            my $shipping          = $cart_fields2[6];
            my $optionids         = $cart_fields2[8];
            my $downladables      = $cart_fields2[10];
            my $altorigin         = $cart_fields2[11];
            my $nontaxable        = $cart_fields2[12];
            my $cartuser5         = $cart_fields2[13];
            my $cartuser6         = $cart_fields2[14];
            my $formattedoptions  = $cart_fields2[15];
            my $priceafteroptions = $cart_fields2[16];

            if ( $downladables ) {
                $productStatus = "$agora_downloadable_lang";
            }
            else {
                $productStatus = "$sc_defaultProductStatus";
            }
            $cart_lines_for_logging .=
"$quantity|$pid|$category|$price|$product|$shipping|$optionids|$downladables|$altorigin|$nontaxable|$cartuser5|$cartuser6|$formattedoptions|$priceafteroptions|$productStatus";
            if ( $sc_write_product_sales_logs =~ /yes/i ) {
                my $productNameThngy = "$product    ID $pid";
                $productsSold{$productNameThngy} += $quantity;
            }
        }
        close(CART);
        release_file_lock("$sc_cart_path.lockfile");
    }

    $orderLoggingHash{'cartContents'} = $cart_lines_for_logging;

    $orderLogString =
"$year\t$month\t$day\t$orderLoggingHash{'cart_invoiceNumber'}\t$orderLoggingHash{'cart_and_order_id'}\t$orderLoggingHash{'orderStatus'}\t$orderLoggingHash{'shiptrackingID'}\t$orderLoggingHash{'firstName'}\t$orderLoggingHash{'lastName'}\t$orderLoggingHash{'fullName'}\t$orderLoggingHash{'companyName'}\t$orderLoggingHash{'customerPhone'}\t$orderLoggingHash{'faxNumber'}\t$orderLoggingHash{'emailAddress'}\t$orderLoggingHash{'orderFromAddress'}\t$orderLoggingHash{'customerAddress2'}\t$orderLoggingHash{'customerAddress3'}\t$orderLoggingHash{'orderFromCity'}\t$orderLoggingHash{'orderFromState'}\t$orderLoggingHash{'orderFromPostal'}\t$orderLoggingHash{'orderFromCountry'}\t$orderLoggingHash{'shipToName'}\t$orderLoggingHash{'shipToAddress'}\t$orderLoggingHash{'shipToAddress2'}\t$orderLoggingHash{'shipToAddress3'}\t$orderLoggingHash{'shipToCity'}\t$orderLoggingHash{'shipToState'}\t$orderLoggingHash{'shipToPostal'}\t$orderLoggingHash{'shipToCountry'}\t$orderLoggingHash{'shiptoResidential'}\t$orderLoggingHash{'insureShipment'}\t$orderLoggingHash{'shipMethod'}\t$orderLoggingHash{'shippingTotal'}\t$orderLoggingHash{'salesTax'}\t$orderLoggingHash{'tax1'}\t$orderLoggingHash{'tax2'}\t$orderLoggingHash{'tax3'}\t$orderLoggingHash{'discounts'}\t$orderLoggingHash{'netProfit'}\t$orderLoggingHash{'subTotal'}\t$orderLoggingHash{'orderTotal'}\t$orderLoggingHash{'affiliateTotal'}\t$orderLoggingHash{'affiliateID'}\t$orderLoggingHash{'affiliateMisc'}\t$orderLoggingHash{'user1'}\t$orderLoggingHash{'user2'}\t$orderLoggingHash{'user3'}\t$orderLoggingHash{'user4'}\t$orderLoggingHash{'user5'}\t$orderLoggingHash{'adminMessages'}\t$orderLoggingHash{'cartContents'}\t$orderLoggingHash{'GatewayUsed'}\t$orderLoggingHash{'shippingMessages'}\t$orderLoggingHash{'xcomments'}\t$orderLoggingHash{'termsOfService'}\t$orderLoggingHash{'discountCode'}\t$orderLoggingHash{'user6'}\t$orderLoggingHash{'user7'}\t$orderLoggingHash{'user8'}\t$orderLoggingHash{'user9'}\t$orderLoggingHash{'user10'}\t$orderLoggingHash{'buySafe'}\t$orderLoggingHash{'order_payment_status'}\t$orderLoggingHash{'order_payment_type_user1'}\t$orderLoggingHash{'GiftCard_number'}\t$orderLoggingHash{'GiftCard_amount_used'}\t$orderLoggingHash{'internal_company_notes1'}\t$orderLoggingHash{'internal_company_notes2'}\t$orderLoggingHash{'internal_company_notes2'}\t$orderLoggingHash{'customer_order_notes1'}\t$orderLoggingHash{'customer_order_notes2'}\t$orderLoggingHash{'customer_order_notes3'}\t$orderLoggingHash{'customer_order_notesDLtext'}\t$orderLoggingHash{'customer_order_notesDLhtml'}\t$orderLoggingHash{'mailinglist_subscribe'}\t$orderLoggingHash{'wishlist_subscribe'}\t$orderLoggingHash{'insurance_cost'}\t$orderLoggingHash{'trade_in_allowance'}\t$orderLoggingHash{'rma_number'}\t$orderLoggingHash{'customer_contact_notes1'}\t$orderLoggingHash{'customer_contact_notes2'}\t$orderLoggingHash{'account_number'}\t$orderLoggingHash{'sales_rep'}\t$orderLoggingHash{'sales_rep_notes1'}\t$orderLoggingHash{'sales_rep_notes2'}\t$orderLoggingHash{'how_did_you_find_us'}\t$orderLoggingHash{'suggestion_box'}\t$orderLoggingHash{'preferrred_shipping_date'}\t$orderLoggingHash{'ship_order_items_as_available'}\t$orderLoggingHash{'shipToCompany'}\t$orderLoggingHash{'member'}\t$orderLoggingHash{'pricingLevel'}\t$orderLoggingHash{'orderDate'}\n";

    $orderShortLogString =
"$year\t$month\t$day\t$orderLoggingHash{'cart_invoiceNumber'}\t$orderLoggingHash{'cart_and_order_id'}\t$orderLoggingHash{'orderStatus'}\t$orderLoggingHash{'firstName'}\t$orderLoggingHash{'lastName'}\t$orderLoggingHash{'fullName'}\t$orderLoggingHash{'companyName'}\t$orderLoggingHash{'emailAddress'}\t$orderLoggingHash{'orderFromState'}\t$orderLoggingHash{'orderFromPostal'}\t$orderLoggingHash{'orderFromCountry'}\t$orderLoggingHash{'shipMethod'}\t$orderLoggingHash{'shippingTotal'}\t$orderLoggingHash{'salesTax'}\t$orderLoggingHash{'tax1'}\t$orderLoggingHash{'tax2'}\t$orderLoggingHash{'tax3'}\t$orderLoggingHash{'discounts'}\t$orderLoggingHash{'netProfit'}\t$orderLoggingHash{'subTotal'}\t$orderLoggingHash{'orderTotal'}\t$orderLoggingHash{'affiliateTotal'}\t$orderLoggingHash{'affiliateID'}\t$orderLoggingHash{'affiliateMisc'}\t$orderLoggingHash{'GatewayUsed'}\t$orderLoggingHash{'buySafe'}\n";

    codehook( 'log_order_top' );

    # test for year and months as directory names for logging purposes.
    if ( !( -d $filename2 ) ) {
        mkdir $filename2;
    }
    if ( !( -d $filename3 ) ) {
        mkdir $filename3;
    }

    if ( $sc_write_monthly_short_order_logs =~ /yes/i ) {
        $filename4 = "$filename3/$month$year" . '_indexOrderLog.log2';
        get_file_lock("$filename4.lockfile");
        open( ORDERLOG4, ">>$filename4" );
        print ORDERLOG4 $orderShortLogString;
        close(ORDERLOG4);
        release_file_lock("$filename4.lockfile");
    }

    if ( $sc_write_monthly_master_order_logs =~ /yes/i ) {
        $filename5 = "$filename2/$month$year" . '_MasterOrderLog.log2';
        get_file_lock("$filename5.lockfile");
        open( ORDERLOG, ">>$filename5" );
        print ORDERLOG $orderLogString;
        close(ORDERLOG);
        release_file_lock("$filename5.lockfile");
    }

    if ( $sc_write_individual_order_logs =~ /yes/i ) {
        # write out individual orders.
        $filename5 = "$filename3/${invoice}-${customer_id}-orderdata2";

        codehook( 'log_order_individual_inside_top' );

        get_file_lock("$filename5.lockfile");
        open( ORDERLOG, ">$filename5" );
        print ORDERLOG $orderLogString;
        close(ORDERLOG);
        release_file_lock("$filename5.lockfile");

        codehook( 'log_order_individual_inside_bottom' );
    }

    codehook( 'log_order_middle' );

    if ( $sc_write_product_sales_logs =~ /yes/i ) {
        {
            @keys =
              sort { $productsSold{$a} <=> $productsSold{$b} }
              keys(%productsSold)
        }
        get_file_lock("$filename7.lockfile");
        open( PRODLOG, ">$filename7" );
        foreach $key (@keys) {
            print PRODLOG qq~$key\t$productsSold{$key}\n~;
        }
        close(PRODLOG);
        release_file_lock("$filename7.lockfile");
    }

    if ( $sc_send_order_to_log =~ /yes/i ) {
        # write to the common order log
        $filename = "$sc_logs_dir/$sc_order_log_name";
        get_file_lock("$filename.lockfile");
        open( ORDERLOG, "+>>$filename" );
        $overview_string = "$orderShortLogString";
        codehook('log_order_overview_inside_bottom');
        print ORDERLOG $overview_string;
        close(ORDERLOG);
        release_file_lock("$filename.lockfile");
    }

    codehook( 'log_order_bot' );

}

#######################################################################
#                    cart_thanks_table_header Subroutine
#######################################################################
#special cart contents headers for thanks tables

sub cart_thanks_table_header {

    codehook( 'cart_thanks_table_header_top' );

    if ( $sc_skip_store_header_at_thankyou ne 'yes' ) {
        CheckoutStoreHeader();
    }

    $hidden_fields = make_hidden_fields();

    codehook( 'cart_thanks_table_header' );

    if ( $special_message ) {
        print $special_message;
    }

    $sc_table_form_type_2 =~ s/\[\[sc_cart_contents_table_width\]\]/$sc_cart_contents_table_width/;
    print $sc_table_form_type_2;
    print $hidden_fields;
    print $sc_cart_items_table;
    #print $modify_type;

    # @sc_cart_display_fields is the list of all of the table
    # headers to be displayed in the cart display table and is
    # defined in the manager

    foreach $field (@sc_cart_display_fields) {

        codehook('display_cart_heading_item');

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

    print "</div><!-- thead -->\n\n"

}

#######################################################################
#                    display_thanks_cart_table Subroutine
#######################################################################
#special cart display for thanks tables

sub display_thanks_cart_table {

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

    if ( $sc_global_bot_tracker ne '1' ) {    # run only if not a bot

        &cart_thanks_table_header();

        if ( !( -f "$sc_cart_path" ) ) {    #doesn't exist, create a null file
            open( CART, ">$sc_cart_path" )
              || file_open_error("$sc_cart_path", 'display_cart_contents create null file',__FILE__,__LINE__);
            close(CART);
        }

        open( CART, "$sc_cart_path" )
          || file_open_error( "$sc_cart_path", "display_cart_contents",__FILE__, __LINE__ );


        while (<CART>) {

            print qq|<div class="trow">\n|;
            chomp;

            my $temp = $_;
            local @cart_fields = split( /\|/, $temp );
            local $cart_row_number = pop(@cart_fields);
            push( @cart_fields, $cart_row_number );
            $cart_copy{$cart_row_number} = $temp;

            my $quantity   = $cart_fields[ $cart{'quantity'} ];
            my $product_id = $cart_fields[ $cart{'product_id'} ];

            # taxable or non-table.
            $isTaxable = $cart_fields[ $cart{'user4'} ];

            if ( !( $sc_db_lib_was_loaded =~ /yes/i ) ) {
                require_supporting_libraries( __FILE__, __LINE__, "$sc_db_lib_path" );
            }

            undef(@db_row);
            $found_it = check_db_with_product_id( $product_id, *db_row );

            my $item_agorascript = q{};

            foreach my $zzzitem (@db_row) {
                my $field = $zzzitem;
                if ( $field =~ /^%%OPTION%%/i ) {
                    ( $empty, $option_tag, $option_location ) = split( /%%/, $field );
                    $field = load_opt_file($option_location);
                    $item_agorascript .= $field;
                }
            }
            codehook( 'display_cart_item_agorascript' );
            my $zzfield =
              agorascript( $item_agorascript, 'display-cart', "$product_id",__FILE__, __LINE__ );

            $total_quantity += $quantity;

            my $display_counter = 0;

            my $temp_fieldname_indicator = q{};
            foreach my $field_name (@sc_col_name) {
                if (   ( $field_name eq 'web_options' )
                    || ( $field_name eq 'options' )
                    || ( $field_name eq 'email_options' ) )
                {
                    $temp_fieldname_indicator = '1';
                }
            }

            foreach my $field_name (@sc_col_name) {

                my $display_index = $cart{$field_name};
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
                    $cart_cell = $sc_cart_contents_table{'Generic TD type Cell'};
                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                    print $cart_cell;
                }
                elsif ( $display_index == $sc_cart_index_of_price ) {
                    $price = display_price($display_me);
                    $cart_cell = $sc_cart_contents_table{'Price or Total Cell'};
                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$price/;
                    print $cart_cell;
                }
                elsif ( $display_index == $sc_cart_index_of_price_after_options ) {
                    $lineTotal = format_price($display_me);
                    $lineTotal = display_price($lineTotal);
                    $cart_cell = $sc_cart_contents_table{'Price or Total Cell'};
                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$lineTotal/;
                    print $cart_cell;
                }
                elsif ( ( $field_name eq 'web_options' ) || ( $field_name eq 'options' ) || ( $field_name eq 'email_options' ) ) {
                    #skip
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

                    # if field starts with [[IMG]] then it is an image, and will will generate an HTML IMG tag for it
                    if ( $display_me =~ /^\[\[img\]\]/i ) {
                        ( $image_tag, $image_location ) = split( /\]\]/, $display_me );
                        $display_me =
                            '<img src="'
                          . "$sc_SSL_base_URL$URL_of_images_directory/$image_location"
                          . '" alt="'
                          . "$image_location" . '">';

                    } elsif ( $display_me =~ /^%%IMG%%/i ) {
                        ( $empty, $image_tag, $image_location ) = split ( /%%/, $display_me );
                        $display_me = '<img src="'
                        . "$sc_SSL_base_URL$URL_of_images_directory/$image_location"
                        . '" alt="' . "$image_location" . '">';
                    }
                    if ( $temp =~ /image/ ) {
                        $display_me =~ s/\[\[URLofImages\]\]/$URL_of_images_directory/g;
                        $cart_cell = $sc_cart_contents_table{'Thanks Mini Image Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                        print $cart_cell;
                    }
                    elsif ( $temp =~ /shipping/ ) {
                        if ( $sc_use_SBW =~ /yes/i ) {
                            $display_me = $display_me;
                        }
                        else {    # display total price
                            $display_me = display_price($display_me);
                        }

                        $cart_cell = $sc_cart_contents_table{'Shipping Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$lineTotal/;
                        print $cart_cell;
                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Generic TD type Cell'};
                        $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                        $cart_cell =~ s/\[\[displayme\]\]/$lineTotal/;
                    }

                }
                elsif ( $display_index == $sc_cart_index_of_image ) {
                    $display_me = $cart_fields[$display_index];
                    $display_me =~ s/\[\[URLofImages\]\]/$sc_SSL_base_URL$URL_of_images_directory/g;
                    $cart_cell = $sc_cart_contents_table{'Thanks Mini Image Cell'};
                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                    print $cart_cell;
                }
                elsif ( $display_index == $sc_cart_index_of_measured_value ) {
                    if ( $sc_use_SBW =~ /yes/i ) {    #display total pounds
                        $shipping_price = $display_me;
                    }
                    else {                            # display total price
                        $shipping_price = display_price($display_me);
                    }
                    $cart_cell = $sc_cart_contents_table{'Shipping Cell'};
                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$shipping_price/;
                    print $cart_cell;
                }

                elsif ( $field_name eq 'name' ) {
                    if (   ( $temp_fieldname_indicator eq '1' ) && ( $cart_fields[15] ) )  {
                        my @ans_opts =
                          split( /$sc_opt_sep_marker/, $cart_fields[15] );
                        my $ans2 = join "$sc_cart_table_optionline_setup",
                          @ans_opts;
                          $cart_cell = $sc_cart_contents_table{'Thanks Product Name with Options Cell'};
                          $cart_cell =~ s/\[\[optionanswer\]\]/$sc_cart_table_optionline_setup $ans2/;
                    }
                    else {
                        $cart_cell = $sc_cart_contents_table{'Thanks Product Name Cell'};
                    }
                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$display_me/;
                    print $cart_cell;
                }
                else {
                    $cart_cell = $sc_cart_contents_table{'Generic TD type Cell'};
                    $cart_cell =~ s/\[\[fieldname\]\]/$display_name/;
                    $cart_cell =~ s/\[\[displayme\]\]/$lineTotal/;
                    print $cart_cell;
                }

                $display_counter++;

                # End of foreach $display_index (@sc_cart_index_for_display)
            }

            # create the shipping info for SBW module and totals
            $total_measured_quantity = $total_measured_quantity + $quantity * $cart_fields[6];
            $shipping_total = $total_measured_quantity;

            # alt origin postal code adds postal code to stevo for shipping
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

            # dimensional shipping data added to stevo for shipping
            if ( $sc_dimensional_shipping_enabled =~ /yes/i ) {
                $stevo_shipping_thing .= $cart_fields[13];
            }

            $unformatted_subtotal =  ( $cart_fields[$sc_cart_index_of_price_after_options] );
            $subtotal = format_price( $quantity * $unformatted_subtotal );
            $unformatted_grand_total = $grand_total + $subtotal;
            $grand_total   = format_price($unformatted_grand_total);

            # taxable or non-table.
            if ( $isTaxable !~ /yes/i ) {
                $unformatted_taxable_grand_total = $taxable_grand_total + $subtotal;
                $taxable_grand_total =  format_price($unformatted_taxable_grand_total);
            }

            $price = display_price($subtotal);

            print $sc_cart_item_trow_end_tags;

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

        print "</div>"; # fix layouts for thankyou page

        cart_table_footer($price);

        display_calculations( $taxable_grand_total, $grand_total, 'before', $total_measured_quantity );

    }    # end of "run only if not a bot"

    #End of display_thanks_cart_table
}

########################################################################

1;
