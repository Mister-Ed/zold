$versions{'loader_routines.pl'} = '06.6.00.0000';
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
# Contains the subroutines/functions for loading library sets for:
#       cart libs
#       product libs
#       order libs
#
#

########################################################################
# reduce retyping file loading

sub load_cart_libs {

    require_supporting_libraries( __FILE__, __LINE__,
        "$sc_syscart_dir/cart.pl",
        "$sc_syscart_dir/cart_totals.pl" );

}
#######################################################################
# reduce retyping file loading

sub load_product_libs {

    require_supporting_libraries( __FILE__, __LINE__,
        "$sc_sysview_dir/page_display_product.pl",
        "$sc_sysview_dir/option_files.pl" );

}
#######################################################################
# reduce retyping file loading

sub load_order_libs {

    require_supporting_libraries( __FILE__, __LINE__,
        "$sc_sysview_dir/option_files.pl",
        "$sc_syscheckout_dir/agora_order_lib.pl",
        "$sc_syscheckout_dir/order_email_helpers.pl",
        "$sc_syscheckout_dir/credit_card_validation_lib.pl",
        "$sc_syscheckout_dir/order_processing.pl" );

}
#######################################################################

#######################################################################
#                         Load Order Lib Section
#
# This routine allows the order lib and other core files to be reloaded
# for the agora.cgi ecommerce functions
#
# Moved here to allow different header statuses to be used and to prevent
# http headers from being printed twice.
#
#######################################################################

sub load_order_lib_section {
    # May want to change the header for no-cache under certain circumstances
    agora_starter_section();
    codehook( 'load_order_lib_before' );
    require_supporting_libraries( __FILE__, __LINE__,
        './system66/view/widgets_agorascript.pl',
        "$sc_html_setup_file_path",
        "$sc_order_lib_path" );
    codehook( 'load_order_lib_after' );
}

#######################################################################
1;
