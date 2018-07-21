#!/usr/bin/sh
release=1

print_usage()
{
    cat <<ENDOFUSAGE
add_survey_trip.sh, release $release

Create therion templates for scanned survey notes, decreasing the amount of
time necessary for doing the mundane job of creating plan, profile, and
cross-section scraps for each scanned page of survey.

   -s, --survey     Name of survey.
   -d, --therion_survey_dir
		    Directory which will hold the therion .th2 files created by
                    this script. Directory will be created if needed.
   -n, --notes_dir  Directory which contains the scanned survey notes. All of
                    the image files in this directory will be present to you
                    as this script runs, so you most likely want to have one
                    survey per directory.
   -h, --help       This usage information.

Scrap names are determined based on the image filename and the number of scraps
of a given type in that particular scanned image. All of the images in the dir
specified by (-n/--notes_dir) will processed. For example, what follows is
a list of hypothetical scraps generated for a file called "survey_b.png" which
contained 2 plan view sketches, 1 profile sketch, and 5 cross-sections.
survey_b_pg_1_pl_1
survey_b_pg_1_pl_2
survey_b_pg_1_pr_1
survey_b_pg_1_xs_1
survey_b_pg_1_xs_2
survey_b_pg_1_xs_3
survey_b_pg_1_xs_4
survey_b_pg_1_xs_5

The therion markup for the above scraps would be written in a file called
survey_b_pg1.th2 in the directory specified by -d/--therion_survey_dir. Also
created in this directory is a file with a .th extension and filename matching
your survey name (-s/--survey). This file links all the scraps into a common
survey which you then manually can tie in with the rest of your survey.

Processing scanned notes:
The workflow for actually classifying scraps in a given scanned image is clunky
by straightforward. You will look at the image and determined how many separate
chunks of sketch there are for each type of scrap: plan view, profile, and
cross-section.  The above example survey_b_pg_1 would be entered as follows:
-p2 -r1 -x5
For scans which contain no scrap data, e.g. if the image contains raw survey
data only, simply press enter to proceed to the next image.
ENDOFUSAGE
}

argv=$( getopt --long "help,survey:,therion_survey_dir:,notes_dir:" \
	       --options "hs:d:n:" -n "add_survey_trip.sh" -- "$@" )

eval set -- "$argv"
unset argv

while true; do
    case "$1" in
	'-h'|'--help')
	    print_usage && exit 0
	    ;;
	'-s'|'--survey')
	    shift && survey="$1"
	    ;;
	'-d'|'--therion_survey_dir')
	    shift && dir_survey_files="$1"
	    ;;
	'-n'|'--notes_dir')
	    shift && dir_survey_notes="$1"
	    ;;
	'--')
	    shift && break
	    ;;
	*)
	    print_usage >&2 && exit 1
	    ;;
    esac
    shift
done

file_survey_th="$dir_survey_files/$survey.th"

check_necessaries ()
{
    if [ "$survey"x == x ]; then
	echo 'Must specify -s/--survey' >&2
	exit_after_checks=1
    fi

    if [ "$dir_survey_files"x == x ]; then
	echo 'Must specifiy valid dir for -d/--therion_survey_dir' >&2
	exit_after_checks=1
    fi

    if [ ! -d "$dir_survey_notes" ]; then
	echo 'Must specifiy existing dir for -n/--notes_dir' >&2
	exit_after_checks=1
    fi

    if [ -f "$file_survey_th" ]; then
	echo "Survey file '$file_survey_th' already exists." >&2
	exit_after_checks=1
    fi

    test "$exit_after_checks" == 1 && exit 1
}

window_display_get ()
{
    ps -a | grep display || display &
    xwininfo -name "ImageMagick: " | sed -n 's/^.*Window id: \(.*\) "ImageMagick: "$/\1/p'
}

therion_file_th2_header_print ()
{
local file4identify=$( echo "$2" | sed 's:^../::' )
# this hacky eval nastiness is used to get the dimensions of the current sketch
eval $( identify -verbose "$file4identify" | sed -n 's/^  Page geometry: \([0-9]\+\)x\([0-9]\+\).*$/local sketch_w=\1; local sketch_h=\2;/p' )
sketch_w=$(( $sketch_w+128 ))
sketch_h=$(( $sketch_h+128 ))
cat <<EOF> "$1"
encoding  utf-8
##XTHERION## xth_me_area_adjust -128 -$sketch_h $sketch_w 128
##XTHERION## xth_me_area_zoom_to 100
##XTHERION## xth_me_image_insert {0 1 1.0} {0 {}} {$2} 0 {}

EOF
}

# $1 projection type
# $2 path to .th2 file
# $3 name of scrap
# $4 path fo sketch image file
therion_file_scrap_print ()
{
cat <<EOF>> "$2"
scrap $3 -projection $1 -scale [0 0 400 0 0.0 0.0 20 0.0 ft] -sketch [$4] 0 -2200

endscrap
EOF
}

check_necessaries

test -d "$dir_survey_files" || mkdir "$dir_survey_files"

window_id="`window_display_get`"
survey_plan_map_def="map $survey -proj plan\n"
survey_prof_map_def="map $survey""_profile -proj extended\n"
x_sections=""
echo "encoding  utf-8" > "$file_survey_th"
for page in "$dir_survey_notes"/*; do
    display -window "$window_id" "$page"
    echo "$page:"
    echo "sketches? -pN -rN -xN"
    read -p "? " sketches
    if [ "$sketches"x != x ]; then
	sketch_page=`basename "$page" | sed 's:\.[^\.]\+$::; s: :_:g'`
	file_sketch_th2="$sketch_page.th2"
	therion_file_th2_header_print "$dir_survey_files/$file_sketch_th2" "../$page"

	# TODO: what follow is super awful. this is the oldest part of the code and
	# grew from a hack that was thrown together very hastily. this should be
	# rewritten to NOT use getopts which is too verbose.
	while getopts "p:r:x:" scrap $sketches; do
	    case $scrap in
		p)
		    for n in `seq 1 $OPTARG`; do
			scrap_name="$sketch_page"_pl_"$n"
			therion_file_scrap_print			\
			    plan					\
			    "$dir_survey_files/$file_sketch_th2"	\
			    "$scrap_name"				\
			    "../$page"
			survey_plan_map_def="$survey_plan_map_def  $scrap_name\n"
		    done
		    ;;
		r)
		    for n in `seq 1 $OPTARG`; do
			scrap_name="$sketch_page"_pr_"$n"
			therion_file_scrap_print			\
			    extended					\
			    "$dir_survey_files/$file_sketch_th2"	\
			    "$scrap_name"				\
			    "../$page"
			survey_prof_map_def="$survey_prof_map_def  $scrap_name\n"
		    done
		    ;;
		x)
		    for n in `seq 1 $OPTARG`; do
			scrap_name="$sketch_page"_xs_"$n"
			therion_file_scrap_print			\
			    none					\
			    "$dir_survey_files/$file_sketch_th2"	\
			    "$scrap_name"				\
			    "../$page"
			x_sections="$x_sections\n#$scrap_name"
		    done
		    ;;
	    esac
	done
	>> "$file_survey_th" echo "input $file_sketch_th2"
	OPTIND=1
    else
	:
    fi
done

survey_plan_map_def="$survey_plan_map_def""endmap $survey\n"
survey_prof_map_def="$survey_prof_map_def""endmap $survey\n"

if [ "$x_sections"x != x ]; then
    >> "$file_survey_th" echo -e "\n#Available cross-sections:$x_sections"
fi

>> "$file_survey_th" echo -e "\n$survey_plan_map_def"

if [ `echo -ne "$survey_prof_map_def" | wc -l` -gt 2 ]; then
    >> "$file_survey_th" echo -e "\n$survey_prof_map_def"
fi

#echo "input $survey/$survey.th" >> "$dir_survey_files/../unassigned.th"
