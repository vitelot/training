using Gtk;

function gridGtk()
    win = GtkWindow("CONFIGURE",400,400);
    g = GtkGrid();

    label = GtkLabel("");
    GAccessor.justify(label, Gtk.GConstants.GtkJustification.CENTER)
    GAccessor.markup(label,"<b>Configure parameter set</b>")

    lbl1 = GtkLabel("Date");
    txt1 = GtkEntry()  # a widget for entering text
    set_gtk_property!(txt1, :text, "09.05.18")
    set_gtk_property!(txt1, :tooltip_text, "Date from which we want to extract the timetable.")

    txt2 = GtkEntry();
    set_gtk_property!(txt2, :text, "Block file");
    
    ck1 = GtkCheckButton("Print useful info")
    set_gtk_property!(ck1, :active, true)
    
    ck2 = GtkCheckButton("Save useful info")

    cb1 = GtkComboBoxText();
    cb1_choices = ["one", "two", "three", "four"]
    for choice in cb1_choices
      push!(cb1,choice)
    end
    # Lets set the active element to be "two"
    set_gtk_property!(cb1,:active,1)

    btn1 = GtkButton("run");
    btn2 = GtkButton("abort");

    gb1 = GtkBox(:h); push!(gb1, lbl1); push!(gb1, txt1);
    set_gtk_property!(gb1, :expand, txt1, true);
    
    # Now let's place these graphical elements into the Grid:
    g[1:2, 1] = label;    # Cartesian coordinates, g[x,y]
    g[1:2, 2] = gb1;
    g[1:2, 3] = txt2;  # spans both columns
    g[1:2, 4] = cb1;
    g[1  , 5] = ck1;
    g[2  , 5] = ck2;
    g[1  , 6] = btn1;
    g[2  , 6] = btn2;
    
    set_gtk_property!(g, :row_homogeneous, true)
    set_gtk_property!(g, :column_homogeneous, true)
    set_gtk_property!(g, :column_spacing, 15)  # introduce a 15-pixel gap between columns
    # set_gtk_property!(g, :expand, label, true)
    push!(win, g)

    showall(win)

    # set button callback
    id = signal_connect(btn1, "button-press-event") do widget, event
        println("\n#######")
        println("txt1: ",get_gtk_property(txt1, :text, String))
        println("txt2: ",get_gtk_property(txt2, :text, String))
        println("cb1: ",cb1_choices[1+get_gtk_property(cb1, :active, Int)])
        println("ck1: ",get_gtk_property(ck1, :active, Bool))
        println("ck2: ",get_gtk_property(ck2, :active, Bool))
        println("#######")
        # include("child.jl")
    end
    id = signal_connect(btn2, "button-press-event") do widget, event
        destroy(win);
        exit();
        # return;
    end

    while true
        println("(hit enter to end session)")
        input = readline()
        if input == ""
            break
        end
    end

    return;
end;


gridGtk();

exit()
