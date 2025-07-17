$versions{'dates.pl'} = '06.6.00.0001';

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


#######################################################################
#                      get_date Subroutine
#######################################################################
# get_date is used to get the current date and time and
# format it into a readable form.  The subroutine takes no
# arguments and is called with the following syntax:
#
# $date = &get_date;
#
# It will return the value of the current date, so you
# must assign it to a variable in the calling routine if
# you are going to use the value.

sub get_date {
    local ( @days, @months );
    local ($connector) = $date_to_time_connector;
    @days   = @norm_days;
    @months = @norm_months;
    return get_date_engine();
}

#######################################################################

sub get_date_short {
    local ( @days, @months );
    local ($connector) = ' ';
    @days   = @short_days;
    @months = @short_months;
    return get_date_engine();
}

#######################################################################

sub get_month_year {
    local ( @days, @months );
    local ($connector) = $date_to_time_connector;
    @days   = @norm_days;
    @months = @norm_months;
    return get_monthyear_engine();
}

#######################################################################

sub get_date_engine {

    # The subroutine begins by defining some local working
    # variables
    local ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst,
        $date );

    # Next, it uses the localtime command to get the current
    # time, from the value returned by the time
    # command, splitting it into variables.
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);

    # Then the script formats the variables and assign them to
    # the final $date variable.
    if ( $hour < 10 )

    {
        $hour = "0$hour";
    }

    if ( $min < 10 )

    {
        $min = "0$min";
    }

    if ( $sec < 10 )

    {
        $sec = "0$sec";
    }

    $year += 1900;
    $date =
        "$days[$wday], $months[$mon] $mday, $year"
      . $connector
      . "$hour\:$min\:$sec";

    return $date;

}

#######################################################################

sub get_monthyear_engine {

    # The subroutine begins by defining some local working
    # variables
    my ( $sec, $min, $hour, $mday, $mon, $wday, $yday, $isdst );
    my ( $month, $year );

    # Next, it uses the localtime command to get the current
    # time, from the value returned by the time
    # command, splitting it into variables.
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);

    # Then the script formats the variables and assign them to
    # the final $date variable.
    $year += 1900;
    $month = "$months[$mon]";

    return ( $mday, $month, $year );

}

#######################################################################
#                   get_date_from_epox_provided
#######################################################################
# Added by Mister Ed January 17, 2020

sub get_date_from_epox_provided {

    my ( $sec, $min, $hour, $mday, $mon, $wday, $yday, $isdst );
    my ( $month, $year );
    my $epox_time = shift;

    # Uses the localtime command to get the current
    # time, from the value returned by the time
    # command, splitting it into variables.

    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime($epox_time);

    $year += 1900; # need to add for 1900's
    $month = "$short_months[$mon]";

    return ( "$month $mday, $year $hour:$min:$sec"  );

}

#######################################################################

1;
