{

PRT test 1811: State of for loop index after loop

    Test undefined value of loop index after for.
    ISO 7185 6.8.3.9

}

program iso7185prt1811(output);

var i: integer;

begin

   for i := 1 to 10 do begin

      write(i:1, ' ')

   end;
   write(i:1)

end.