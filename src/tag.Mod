MODULE tag;
IMPORT Out, Strings := ooc2Strings,
       opts, xattr, StringList, strTypes, strUtils;

VAR
  namespace, field, userTags: ARRAY 64 OF CHAR;

PROCEDURE FoundTag(tags: StringList.TStringList; tag: ARRAY OF CHAR): BOOLEAN;
VAR
  index: LONGINT;
BEGIN
  index := StringList.IndexOf(tags, tag);
  IF index >= 0 THEN
    Out.String("Tag '"); Out.String(tag); Out.String("' found at index "); Out.Int(index, 0); Out.Ln;
    RETURN TRUE;
  ELSE
    Out.String("Tag '"); Out.String(tag); Out.String("' not found in list."); Out.Ln;
    RETURN FALSE;
  END;
END FoundTag;

PROCEDURE CommaSeparatedToStringList(VAR input: ARRAY OF CHAR; ttags: StringList.TStringList);
VAR
  i, startPos, length: INTEGER;
  tempTag: ARRAY 256 OF CHAR;
  tempRes: LONGINT;
BEGIN
  Out.String("CommaSeparatedToStringList called"); Out.Ln;
  startPos := 0;
  i := 0;

  WHILE i <= Strings.Length(input) DO
    IF (input[i] = ',') OR (input[i] = 0X) THEN
      (* Extract the tag *)
      length := i - startPos;
      IF length > 0 THEN
        Strings.Extract(input, startPos, length, tempTag);
        tempTag[length] := 0X; (* Null-terminate the string *)

        (* Skip any leading or trailing spaces *)
        IF tempTag[0] = ' ' THEN
          Strings.Extract(tempTag, 1, length - 1, tempTag);
        END;

        (* Debugging output to show the extracted tag and each character *)
        Out.String("Extracted tag: '"); Out.String(tempTag); Out.String("'. Characters: ");
        FOR startPos := 0 TO Strings.Length(tempTag) - 1 DO
          Out.Char(tempTag[startPos]); Out.String("("); Out.Int(ORD(tempTag[startPos]), 0); Out.String(") ");
        END;
        Out.Ln;

        (* Add the tag to the list *)
        tempRes := StringList.AddString(ttags, tempTag);
      END;

      (* Move startPos to the next position after the comma *)
      startPos := i + 2; (* Skip over ", " if there's a space after the comma *)
    END;
    INC(i);
  END;
END CommaSeparatedToStringList;

PROCEDURE StringListToCommaSeparated(ttags: StringList.TStringList; VAR output: ARRAY OF CHAR; VAR totalLength: LONGINT);
VAR
  i: LONGINT;
  tempStr: strTypes.pstring;
BEGIN
  Out.String("entered StringListToCommaSeparated"); Out.Ln;
  Out.String("got ttags:"); Out.Ln;
  StringList.DumpOut(ttags);

  totalLength := 0;
  xattr.zeroStr(output); (* Clear the output string *)

  FOR i := 0 TO ttags.Count - 1 DO
    tempStr := StringList.GetString(ttags, i);

    IF Strings.Length(tempStr^) > 0 THEN
      IF i > 0 THEN
        (* Add a comma and a space between tags *)
        Strings.Append(", ", output);
        INC(totalLength, 2);
      END;

      (* Append the tag to the output string *)
      Strings.Append(tempStr^, output);
      INC(totalLength, Strings.Length(tempStr^));
    END;
  END;

  (* Ensure the output string is properly null-terminated *)
  output[totalLength] := 0X;

  (* Debugging output to verify the final result *)
  Out.String("Final output='"); Out.String(output); Out.Char("'"); Out.Ln;
END StringListToCommaSeparated;

PROCEDURE AddTag(path, tag: ARRAY OF CHAR);
VAR
  tags: ARRAY 1024 OF CHAR;
  ttags: StringList.TStringList;
  res, totalLength: LONGINT;
  tmpres: LONGINT;
BEGIN
  (* Retrieve the list of xattr attributes *)
  ttags := xattr.ListAttr(path, tags, LEN(tags));
  IF ttags # NIL THEN
    Out.String("ttags := xattr.ListAttr"); Out.Ln;
    StringList.DumpOut(ttags);
    Out.Ln;
  ELSE
    Out.String("ttags not found, ListAttr returned NIL"); Out.Ln;
  END;

  IF ttags = NIL THEN
    ttags := StringList.Create();
  ELSE
    (* Get the current value of the user.tags attribute *)
    res := xattr.GetAttr(path, userTags, tags, LEN(tags));
    IF res >= 0 THEN
      (* Convert the comma-separated string to a TStringList *)
      CommaSeparatedToStringList(tags, ttags);
    ELSE
      Out.String("Error fetching the contents of user.tags"); Out.Ln;
    END;
  END;

  (* Skip 'user.tags' if present in the list *)
  IF FoundTag(ttags, userTags) THEN
    Out.String("Skipping user.tags as it is the attribute key"); Out.Ln;
  END;

  (* Check if the tag already exists *)
  IF ~FoundTag(ttags, tag) THEN
    Out.String("tag "); Out.Ln;
    strUtils.dumpChars(tag); Out.Ln;
    Out.String("was not found in ttags"); Out.Ln;

    (* Add the new tag to the TStringList *)
    tmpres := StringList.AddString(ttags, tag);

    (* Convert TStringList back to comma-separated string *)
    StringListToCommaSeparated(ttags, tags, totalLength);

    (* Store the updated tags string as xattr *)
    res := xattr.SetAttr(path, userTags, tags, totalLength, 0);
    IF res < 0 THEN
      Out.String("Error adding tag"); Out.Ln;
    END;
  ELSE
    Out.String("Tag already exists"); Out.Ln;
  END;
END AddTag;

PROCEDURE ListTags(path: ARRAY OF CHAR);
VAR
  tags: ARRAY 1024 OF CHAR;
  ttags: StringList.TStringList;
  res: LONGINT;
BEGIN
  (* Retrieve the user.tags xattr *)
  res := xattr.GetAttr(path, userTags, tags, LEN(tags));

  IF res >= 0 THEN
    ttags := StringList.Create();
    CommaSeparatedToStringList(tags, ttags);

    (* Dump the list of tags *)
    Out.String("Tags: ");
    StringList.DumpOut(ttags);
  ELSE
    Out.String("No tags found"); Out.Ln;
  END;
END ListTags;

PROCEDURE RemoveTag(VAR tags: StringList.TStringList; tag: ARRAY OF CHAR);
VAR
  index: LONGINT;
  foundTag: strTypes.pstring;
BEGIN
  Out.String("Attempting to remove tag: '"); Out.String(tag); Out.String("'"); Out.Ln;

  (* Dump the current list of tags for debugging *)
  Out.String("Current tags in the list:"); Out.Ln;
  FOR index := 0 TO tags.Count - 1 DO
    foundTag := StringList.GetString(tags, index);
    Out.String("Tag in list ["); Out.Int(index, 0); Out.String("]: '"); Out.String(foundTag^); Out.String("'"); Out.Ln;
  END;

  (* Now attempt to find and remove the tag *)
  index := StringList.IndexOf(tags, tag);
  IF index >= 0 THEN
    Out.String("Removing tag: '"); Out.String(tag); Out.String("' at index "); Out.Int(index, 0); Out.Ln;
    tags.Delete(tags, index);  (* Delete the tag at the found index *)
  ELSE
    Out.String("Tag '"); Out.String(tag); Out.String("' not found in TStringList"); Out.Ln;
  END;
END RemoveTag;

PROCEDURE DeleteTag(path, tag: ARRAY OF CHAR);
VAR
  tags: ARRAY 1024 OF CHAR;
  ttags: StringList.TStringList;
  res, totalLength: LONGINT;
  idx: LONGINT;
  nodeToRemove: StringList.Node;
BEGIN
  (* Retrieve the list of xattr attributes *)
  ttags := xattr.ListAttr(path, tags, LEN(tags));

  IF ttags = NIL THEN
    Out.String("No tags found on file"); Out.Ln;
  ELSE
    (* Convert the comma-separated string to TStringList *)
    res := xattr.GetAttr(path, userTags, tags, LEN(tags));
    IF res >= 0 THEN
      CommaSeparatedToStringList(tags, ttags);

      (* Find the index of the tag to delete *)
      idx := ttags.IndexOf(ttags, tag);
      IF idx >= 0 THEN
        nodeToRemove := ttags.Get(ttags, idx);

        (* Check if nodeToRemove is NIL before proceeding *)
        IF nodeToRemove # NIL THEN
          (* Debugging: Output the tag being removed *)
          Out.String("Removing tag: '"); Out.String(nodeToRemove.obj(StringList.TString).str^);
          Out.String("' at index "); Out.Int(idx, 0); Out.Ln;

          IF ttags.DeleteNode(ttags, nodeToRemove) THEN
            Out.String("Node deleted successfully."); Out.Ln;
          ELSE
            Out.String("Failed to delete node."); Out.Ln;
          END;

          (* After deletion, update the xattr *)
          IF ttags.Count > 0 THEN
            StringListToCommaSeparated(ttags, tags, totalLength);
            res := xattr.SetAttr(path, userTags, tags, totalLength, 0);
            IF res < 0 THEN
              Out.String("Error updating tags after deletion"); Out.Ln;
            END;
          ELSE
            res := xattr.RemoveAttr(path, userTags);
            IF res < 0 THEN
              Out.String("Error removing user.tags attribute"); Out.Ln;
            ELSE
              Out.String("All tags removed, user.tags attribute deleted"); Out.Ln;
            END;
          END;
        ELSE
          Out.String("Node to delete is NIL, nothing to delete."); Out.Ln;
        END;
      ELSE
        Out.String("Tag '"); Out.String(tag); Out.String("' not found"); Out.Ln;
      END;
    ELSE
      Out.String("Error fetching the contents of user.tags"); Out.Ln;
    END;
  END;
END DeleteTag;

PROCEDURE ClearTags(path: ARRAY OF CHAR);
VAR
  tmpres: LONGINT;
BEGIN
  tmpres := xattr.RemoveAttr(path, userTags);
END ClearTags;

PROCEDURE processArgs;
VAR
  options: opts.Options;
  foptions: opts.Options;
  opt, fopt: opts.Option;
  tfile, ttag: ARRAY 256 OF CHAR;
BEGIN
  options := opts.createOptions();
  foptions := opts.createOptions();

  opt := opts.createOpt();
  opts.setOptName(opt, "-a");
  opts.setOptLName(opt, "--add");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "add a tag");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-f");
  opts.setOptLName(opt, "--file");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-d");
  opts.setOptLName(opt, "--delete");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-C");
  opts.setOptLName(opt, "--clear");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-l");
  opts.setOptLName(opt, "--list");
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-h");
  opts.setOptLName(opt, "--help");
  opts.setOptDesc(opt, "show this help");
  opts.setOptHasVal(opt, FALSE);
  opts.setOptRequired(opt, FALSE);
  options.add(options, opt);


  foptions := opts.populateOptions(options);

  IF opts.findOpt("-h", options) # NIL THEN
    opts.showHelp(options);
    HALT(1)
  END;

  IF opts.reqsSatisfied(options, foptions) THEN
    Out.String("Required options provided"); Out.Ln;
  ELSE
    opts.showHelp(options);
    HALT(1);
  END;

  (* Debugging: Look for the file option explicitly *)
  Out.String("Looking for value of option: -f"); Out.Ln;
  opts.valOfOpt("-f", foptions, tfile);

  IF tfile # "" THEN
    Out.String("File specified: "); Out.String(tfile); Out.Ln;

    (* Handle other options *)
    IF opts.findOpt("-a", foptions) # NIL THEN
      opts.valOfOpt("-a", foptions, ttag);
      AddTag(tfile, ttag);
    ELSIF opts.findOpt("-d", foptions) # NIL THEN
      opts.valOfOpt("-d", foptions, ttag);
      DeleteTag(tfile, ttag);
    ELSIF opts.findOpt("-C", foptions) # NIL THEN
      ClearTags(tfile);
    ELSIF opts.findOpt("-l", foptions) # NIL THEN
      ListTags(tfile);
    END;
  ELSE
    Out.String("File must be specified with -f"); Out.Ln;
  END;
END processArgs;

BEGIN
  COPY("user", namespace);
  COPY("tags", field);
  COPY(namespace, userTags);
  Strings.Append(".", userTags);
  Strings.Append(field, userTags);
  processArgs;
END tag.

