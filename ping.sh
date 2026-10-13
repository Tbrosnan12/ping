#!/bin/bash

dir=/home/pi/nas/projects/ping_pub
 
name_clean() {
    local name=$1
    name="${name// /+}"
    echo $name
}

arxive_nums() {
    local name=$1
    local file=$dir/meta_data/"${name}".html

    arxive_numbers=($(cat "$file" | grep "https://arxiv.org/abs/" | awk 'BEGIN { FS = "https://arxiv.org/abs/" } ; { print $2 }' | awk 'BEGIN { FS = "\"" } ; { print $1 }'))
    echo "${arxive_numbers[@]}"
}

abstract() {
    local name=$1
    local arxive_no=$2
    local file=$dir/meta_data/"${name}".html

    abstract="$(grep -A100000 "$arxive_no" "$file" | awk -v RS='</summary>' '/<summary>/{ sub(/.*<summary>/, ""); print; exit }')"
    echo "$abstract"
}

title() {
    local name=$1
    local arxive_no=$2
    local file=$dir/meta_data/"${name}".html

    title="$(grep -A100000 "$arxive_no" "$file" | awk -v RS='</title>' '/<title>/{ sub(/.*<title>/, ""); print; exit }')"
    echo "$title"
}

while IFS= read -r line; do
    authors+=("$line")
done <$dir/authors.txt

if [ -d "$dir/meta_data/paper_lists" ]; then
    #mv $dir/meta_data/paper_lists $dir/meta_data/paper_lists_old
    mkdir $dir/meta_data/paper_lists_new    
    echo "Comparing new papers to $dir/meta_data/paper_lists/"
else
    echo "No old comparison arxive snapshot found exiting"
    #exit 0  
fi


new_papers=0
for author in "${authors[@]}"; do
    echo "fetching papers for ""${author}"
    search_name="$( name_clean "$author" )"
 
    site="http://export.arxiv.org/api/query?search_query=au:%22"${search_name}"%22&max_results=1000&sortBy=lastUpdatedDate&sortOrder=descending"
    wget -qO $dir/meta_data/"${author}".html "$site"

    touch $dir/meta_data/paper_lists_new/"${author}".txt
    arxive_numbers=($( arxive_nums "$author" ))
    for arxive_no in "${arxive_numbers[@]}"; do    
        echo "$arxive_no" >> $dir/meta_data/paper_lists_new/"${author}".txt
        if grep -q "$arxive_no" $dir/meta_data/paper_lists/"${author}".txt 2>/dev/null; then
            continue
        else
            echo "New Paper from "${author}" at https://arxiv.org/abs/"${arxive_no}" !"

            file=$dir/meta_data/"${arxive_no}".md
            touch  "$file"
            title="$( title "$author"  "$arxive_no" )"
            abstract="$( abstract "$author"  "$arxive_no" )"
             
            echo "## ""$title" >> "$file"
            echo "" >> "$file"
            echo  "New Paper from ""${author}"" at https://arxiv.org/abs/"${arxive_no}"" >> "$file"  
            echo "" >> "$file"            
            echo "### Abstract:" >> "$file"
            echo "$abstract" >>  "$file"
        
            cat $dir/meta_data/"${arxive_no}".md
            rm $dir/meta_data/"${arxive_no}".md
            new_papers=$(( new_papers + 1 ))
        fi
    done
done

if [ "$new_papers" -gt 0 ]; then
    mv $dir/meta_data/paper_lists_new $dir/meta_data/paper_lists
else
    rm -r $dir/meta_data/paper_lists_new
fi
