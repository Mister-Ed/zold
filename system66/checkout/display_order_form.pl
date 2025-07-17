$versions{'display_order_form.pl'} = '06.6.00.0001';

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


#######################################################################
#                     display_order_form
#######################################################################
#
# subroutine: display_order_form
#   Usage:
#     display_order_form()
#
#   Parameters:
#     None. It outputs the HTML in $sc_html_order_form_path
#     specified in the setup file.
#
#   Output:
#     This routine merely outputs an HTML form with
#     cart specific information.
#
#######################################################################

sub display_order_form {
    local ( $line, $the_file, @lines, $temp ) = q{};
    local ( $subtotal, $taxable_grand_total ) = q{};
    local ( $total_quantity, $total_measured_quantity ) = q{};
    local ($stevo_shipping_thing) = q{};
    local ($hidden_fields) = q{};
    local ($text_of_cart);
    local ($have_form_tag)  = 'no';
    local ($form_name) = "$sc_form_dir_path/$sc_active_gateways[0]-orderform.html";
    local ($have_terminated_form_tag) = 'no';
    local ($continue) = 1;
    local $skip_cart_contents_table = '';

    codehook('order_form_entry');
    if ( $continue == 0 ) { return; }


    # override default $form_name if in donation mode
    if ( $sc_donation_mode eq 'yes' && $sc_donation_orderform_name  && $sc_active_gateways[0] ) {
        $temp = "$sc_form_dir_path/$sc_donation_orderform_name" . '-' . $sc_active_gateways[0] .'-orderform.html';
        if ( -f $temp ) {
            $temp =~ /([^\xFF]*)/;
            $form_name = $1;
        }
    }

    if ( $form_data{'order_form'} ) {
        $temp = "$sc_form_dir_path/$form_data{'order_form'}-orderform.html";

        # override multiple OFN $form_name if in donation mode
        if ( $sc_donation_mode eq 'yes' && $sc_donation_orderform_name ) {
            $temp = "$sc_form_dir_path/$sc_donation_orderform_name"  . '-' .  $form_data{'order_form'} .'-orderform.html';
        }

        if ( -f $temp ) {
            $temp =~ /([^\xFF]*)/;
            $form_name = $1;
        }

    } elsif ( ( $sc_allow_ofn_choice =~ /yes/i ) || ( $sc_gateway_count > 1 ) ) {
        $form_name = "$sc_form_dir_path/combo-orderform.html";
        foreach $zuser (@sc_active_gateways) {
            my $gate .= $zuser . '-user_lib.pl';
            if ( -f "$sc_userpay_conf_dir/$gate" ) {
                require_supporting_libraries( __FILE__, __LINE__, "$sc_userpay_conf_dir/$gate" );
            }
        }

        if ( $sc_gateway_count > 1 ) {
            $gateway_row_remainder = $sc_gateway_count % $sc_show_multi_gateways_per_row;
            $gateway_row_cells_needed = ($sc_gateway_count - $gateway_row_remainder);
            if ( $gateway_row_remainder == 1 ) {
                $gateway_choice_last_cell_div = $sc_template_full_width_div_container;
            }
            if ( $gateway_row_remainder == 2 ) {
                $gateway_choice_last_cell_div = $sc_template_half_width_div_container;
            }
            if ( $sc_show_multi_gateways_per_row eq '1' ) {
                $gateway_choice_normal_cell_div = $sc_template_full_width_div_container;
            }
            elsif ( $sc_show_multi_gateways_per_row eq '3' ) {
                $gateway_choice_normal_cell_div = $sc_template_third_width_div_container
            }
            else {
                $gateway_choice_normal_cell_div = $sc_template_half_width_div_container;
            }

        }

    }
    elsif ( $sc_active_gateways[0] eq '' ) {
        if ( $sc_enable_missing_gateway_logging ne 'no' ) {
            update_error_log( "$agora_error_no_orderform",__FILE__, __LINE__ );
        }
        checkoutFormMissing();
        call_exit();
    }

    # Open the order form file
    # If there is an error, report it to the cart and exit.

    codehook('order_form_pre_read');
    open( ORDERFORM, "$form_name" ) || file_open_error( "$form_name", 'Display Order Form File Error',__FILE__, __LINE__ );

    # The order form is read into
    # $line line by line.
    #
    # This line is then parsed to see if
    # it should be display as-is or
    # if some piece of cart information
    # needs to display.
    #
    # If the <FORM> tag is encountered,
    # then it is replaced with a form tag
    # generated based on values in the setup file
    # for the shopping cart script.
    #
    # Hidden variables such as the page
    # we came from and the current cart_id are
    # passed to the process_order_form later on.
    {
        local $/ = undef;
        $the_file = <ORDERFORM>;
    }

    $the_file = agorascript( $the_file, 'orderform', 'Order Form Prep 1', __FILE__, __LINE__ );

    codehook( 'order_form_prep' );

    # first, need to process the $ vars ...
    $the_file =~ s/\\/\\\\/g;
    $the_file =~ s/\@/\\\@/g;
    $the_file =~ s/\"/\\\"/g;
    $the_file =~ /([^\xFF]*)/;    # untaint
    eval( '$the_file = "' . $1 . '";' );

    $the_file = script_and_substitute( $the_file, 'Order Form Prep 2' );
    @lines = split( /\n/, $the_file );

    my $done = 0;
    foreach my $myline (@lines) {

        $line = $myline . "\n";

        if ( $line =~ /<html>/i ) {
            $line = "$sc_doctype\n<html>\n";
        }
        if ( $line =~ /<\/head>/i ) {
            $line = "  $sc_standard_head_info$sc_noindex_robot_meta_tags\n</head>\n";
        }
        if ( $line =~ /<body/i ) {
            $line = "<body>\n";
        }

        # If we find the form tag, we
        # need to output the order form

        if ( $line =~ /<form/i ) {

            # Min required fields are:
            #<INPUT TYPE = "hidden" NAME = "page" VALUE = "$form_data{'page'}">
            #<INPUT TYPE = "hidden" NAME = "cart_id" VALUE = "$cart_id">

            $hidden_fields = make_hidden_fields();

            if (   ( $have_form_tag eq 'yes' ) && ( $have_terminated_form_tag eq 'no' ) )   {
                # end the cart's tag, start ours
                # Otherwise this is a tag before the first, and we just

                print "</form>\n\n";

                $have_terminated_form_tag = 'yes';
            }
            else {    # have the first tag
                $have_form_tag = 'yes';
            }

            if ( $sc_replace_orderform_form_tags =~ /yes/i ) {

              # changed for buysafe updates.
              #  print qq!\n<form method="post" action="$sc_order_script_url">!;
                print qq!\n<form method="post" action="$sc_stepone_order_script_url">!;
                print $hidden_fields;
            }
            else {
                print "\n$line\n$hidden_fields\n";
            }

            $line = q{};

        }    # End of If Form tag found

        # If we found a tag stating
        # where the cart contents should
        # appear, then we process the
        # cart and display it
        #
        # <H2> tags surrounding
        # a "cart contents" label
        # designates this state as being
        # true

        if ( $line =~ /<h2>cart.*contents.*h2>/i ) {

            # So, we call the display_cart_table
            # routine and pass it "orderform" to
            # let it know to display order form
            # specific information

            # It returns subtotal
            # total quantity of items in the cart
            # total measured quantity of the measurement
            # field specified in the setup file, and
            # the ascii text of the cart (for logging
            # or emailing the order).

            if ( ( $have_form_tag eq 'yes' ) && ( $have_terminated_form_tag eq 'no' ) )   {
                # close out previous one

                print "</form>\n\n";

                $have_terminated_form_tag = 'yes';
            }
            $have_form_tag = 'yes';

            if ( $skip_cart_contents_table && $sc_donation_mode eq 'yes' ) {
                (
                    $taxable_grand_total, $subtotal, $total_quantity,
                    $total_measured_quantity, $stevo_shipping_thing
                ) = dont_display_cart_table('orderform');
            }
            else {
                (
                    $taxable_grand_total, $subtotal, $total_quantity,
                    $total_measured_quantity, $stevo_shipping_thing
                ) = display_cart_table('orderform');
            }

            $line = q{};
            codehook('display_form_cart_contents_bottom');
        }

        # Print the line (assuming it has not changed).

        if ( $line =~ /\<\/body\>/i ) {    # stop printing at the </BODY> tag
                                           # close(ORDERFORM);
            $done = 1;
        }
        elsif ( $line =~ /\<\/html>/i ) {
            $done = 1;
        }
        else {
            codehook('print_order_form_line');
            print $line;
        }

    }    # End of Parsing Order Form


    CheckoutStoreFooter();

}
############################################################


1;
