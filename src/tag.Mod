MODULE tag;
IMPORT Out, Strings := ooc2Strings, opts, xattr, StringList, strTypes, strUtils, UnixFS;

VAR
  namespace, field, userTags: ARRAY 64 OF CHAR;

PROCEDURE FoundTag(tags: StringList.TStringList; tag: ARRAY OF CHAR): BOOLEAN;
VAR
  index: LONGINT;
BEGIN
  index := StringList.IndexOf(tags, tag);
  IF index >= 0 THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END FoundTag;

PROCEDURE CommaSeparatedToStringList(VAR input: ARRAY OF CHAR; ttags: StringList.TStringList);
VAR
  i, startPos, length: INTEGER;
  tempTag: ARRAY 256 OF CHAR;
  tempRes: LONGINT;
BEGIN
  startPos := 0;
  i := 0;

  WHILE i <= Strings.Length(input) DO
    IF (input[i] = ',') OR (input[i] = 0X) THEN
      length := i - startPos;
      IF length > 0 THEN
        Strings.Extract(input, startPos, length, tempTag);
        tempTag[length] := 0X;
        IF tempTag[0] = ' ' THEN
          Strings.Extract(tempTag, 1, length - 1, tempTag);
        END;
        tempRes := StringList.AddString(ttags, tempTag);
      END;
      startPos := i + 2;
    END;
    INC(i);
  END;
END CommaSeparatedToStringList;

PROCEDURE StringListToCommaSeparated(ttags: StringList.TStringList; VAR output: ARRAY OF CHAR; VAR totalLength: LONGINT);
VAR
  i: LONGINT;
  tempStr: strTypes.pstring;
BEGIN
  (*Out.String("entered StringListToCommaSeparated"); Out.Ln;
  Out.String("got ttags:"); Out.Ln;
  StringList.DumpOut(ttags);*)

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
  (*Out.String("Final output='");*)
  Out.String(output);
  (*Out.Char("'"); Out.Ln;*)
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
  (*
  IF ttags # NIL THEN
    Out.String("ttags := xattr.ListAttr"); Out.Ln;
    StringList.DumpOut(ttags);
    Out.Ln;
  ELSE
    Out.String("ttags not found, ListAttr returned NIL"); Out.Ln;
  END;
  *)
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
    (*
    Out.String("tag "); Out.Ln;
    strUtils.dumpChars(tag); Out.Ln;
    Out.String("was not found in ttags"); Out.Ln;
    *)
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
    (*Out.String("Tags: ");*)
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
  (*
  Out.String("Current tags in the list:"); Out.Ln;
  FOR index := 0 TO tags.Count - 1 DO
    foundTag := StringList.GetString(tags, index);
    Out.String("Tag in list ["); Out.Int(index, 0); Out.String("]: '"); Out.String(foundTag^); Out.String("'"); Out.Ln;
  END;
  *)

  (* Now attempt to find and remove the tag *)
  index := StringList.IndexOf(tags, tag);
  IF index >= 0 THEN
    (*Out.String("Removing tag: '"); Out.String(tag); Out.String("' at index "); Out.Int(index, 0); Out.Ln;*)
    tags.Delete(tags, index);  (* Delete the tag at the found index *)
  ELSE
    Out.String("Tag '"); Out.String(tag); Out.String("' not found."); Out.Ln;
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
          (*
          Out.String("Removing tag: '"); Out.String(nodeToRemove.obj(StringList.TString).str^);
          Out.String("' at index "); Out.Int(idx, 0); Out.Ln;
          *)

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

PROCEDURE FilterByTag(tag: ARRAY OF CHAR);
VAR
  fileList: UnixFS.list;
  tags: ARRAY 1024 OF CHAR;
  ttags: StringList.TStringList;
  i, res: LONGINT;
BEGIN
  (* List all files in the current directory *)
  UnixFS.ListDir(".", fileList);

  (* Process each file *)
  i := 0;
  REPEAT
    (* Get the tags associated with the file *)
    res := xattr.GetAttr(fileList^[i].name, userTags, tags, LEN(tags));

    IF res >= 0 THEN
      (* Convert the comma-separated string to a TStringList *)
      ttags := StringList.Create();
      CommaSeparatedToStringList(tags, ttags);

      (* Check if the tag exists in the file's tags *)
      IF FoundTag(ttags, tag) THEN
        (*Out.String("File: ");*) Out.String(fileList^[i].name); Out.Ln;
      END;
    END;
    INC(i)
  UNTIL i = LEN(fileList^) - 1;
END FilterByTag;

PROCEDURE processArgs;
VAR
  options: opts.Options;
  foptions: opts.Options;
  opt, fopt: opts.Option;
  tfile, ttag: ARRAY 256 OF CHAR;
BEGIN
  options := opts.createOptions();
  foptions := opts.createOptions();

  (* Add all the options *)
  opt := opts.createOpt();
  opts.setOptName(opt, "-a");
  opts.setOptLName(opt, "--add");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "add a tag");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-f");
  opts.setOptLName(opt, "--file");
  opts.setOptHasVal(opt, TRUE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-d");
  opts.setOptLName(opt, "--delete");
  opts.setOptHasVal(opt, TRUE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-C");
  opts.setOptLName(opt, "--clear");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-l");
  opts.setOptLName(opt, "--list");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-F");
  opts.setOptLName(opt, "--filter");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "filter files by tag");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-h");
  opts.setOptLName(opt, "--help");
  opts.setOptDesc(opt, "show this help");
  opts.setOptHasVal(opt, FALSE);
  options.add(options, opt);

  (* Populate options from command-line *)
  foptions := opts.populateOptions(options);

  (* Handle the help flag first *)
  IF opts.findOpt("-h", foptions) # NIL THEN
    opts.showHelp(options);
    HALT(1);
  END;

  (* Check if required options are satisfied *)
  IF ~opts.reqsSatisfied(options, foptions) THEN
    opts.showHelp(options);
    HALT(1);
  END;

  (* Now process the options *)
  IF opts.findOpt("-f", foptions) # NIL THEN
    opts.valOfOpt("-f", foptions, tfile);
  END;

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
  ELSIF opts.findOpt("-F", foptions) # NIL THEN
    opts.valOfOpt("-F", foptions, ttag);
    (*Out.String("Filtering files by tag: "); Out.String(ttag); Out.Ln;*)
    FilterByTag(ttag);
  ELSE
    Out.String("Invalid option or no file specified."); Out.Ln;
    opts.showHelp(options);
    HALT(1);
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
