MODULE tag;
IMPORT Out, Strings := ooc2Strings, opts, xattr, StringList, strTypes, strUtils, UnixFS;

VAR
  namespace, field, userTags: ARRAY 64 OF CHAR;

PROCEDURE SetNamespace(prefix: ARRAY OF CHAR);
BEGIN
  IF prefix # "" THEN
    (* Form namespace based on the passed prefix *)
    COPY("user.", userTags);
    Strings.Append(prefix, userTags);
  ELSE
    (* Default to user.tags *)
    COPY("user.tags", userTags);
  END;
END SetNamespace;

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
  totalLength := 0;
  xattr.zeroStr(output); (* Clear the output string *)

  FOR i := 0 TO ttags.Count - 1 DO
    tempStr := StringList.GetString(ttags, i);

    (* Skip the namespace itself from being stored as a tag *)
    IF Strings.Compare(tempStr^, userTags) # 0 THEN
      IF Strings.Length(tempStr^) > 0 THEN
        IF totalLength > 0 THEN
          (* Add a comma and a space between tags *)
          Strings.Append(", ", output);
          INC(totalLength, 2);
        END;

        (* Append the tag to the output string *)
        Strings.Append(tempStr^, output);
        INC(totalLength, Strings.Length(tempStr^));
      END;
    ELSE
      Out.String("Skipping namespace '"); Out.String(userTags); Out.String("' as a tag"); Out.Ln;
    END;
  END;

  (* Ensure the output string is properly null-terminated *)
  output[totalLength] := 0X;

  (* Debugging output to verify the final result *)
  Out.String(output); Out.Ln;
END StringListToCommaSeparated;

PROCEDURE AddTag(path, tag: ARRAY OF CHAR);
VAR
  tags: ARRAY 1024 OF CHAR;
  ttags: StringList.TStringList;
  res, totalLength: LONGINT;
  tmpres: LONGINT;
BEGIN
  (* Retrieve the list of xattr attributes for the specified namespace *)
  res := xattr.GetAttr(path, userTags, tags, LEN(tags));

  IF res >= 0 THEN
    ttags := StringList.Create();
    CommaSeparatedToStringList(tags, ttags);
  ELSE
    (* No existing tags, initialize new tag list *)
    ttags := StringList.Create();
  END;

  (* Ensure the namespace itself is NOT treated as a tag *)
  IF FoundTag(ttags, userTags) THEN
    Out.String("Skipping namespace '"); Out.String(userTags); Out.String("' as a tag"); Out.Ln;
  ELSE
    (* Check if the tag already exists in this namespace *)
    IF ~FoundTag(ttags, tag) THEN
      tmpres := StringList.AddString(ttags, tag);
      StringListToCommaSeparated(ttags, tags, totalLength);

      (* Debugging: Show what we're about to store *)
      Out.String("Storing tags: '"); Out.String(tags); Out.String("' under namespace '"); Out.String(userTags); Out.String("'"); Out.Ln;

      res := xattr.SetAttr(path, userTags, tags, totalLength, 0);
      IF res < 0 THEN
        Out.String("Error adding tag to namespace "); Out.String(userTags); Out.Ln;
      ELSE
        Out.String("Tag '"); Out.String(tag); Out.String("' successfully added to namespace "); Out.String(userTags); Out.Ln;
      END;
    ELSE
      Out.String("Tag '"); Out.String(tag); Out.String("' already exists in namespace "); Out.String(userTags); Out.Ln;
    END;
  END;
END AddTag;

PROCEDURE ListTags(path: ARRAY OF CHAR);
VAR
  tags: ARRAY 1024 OF CHAR;
  ttags: StringList.TStringList;
  res: LONGINT;
BEGIN
  res := xattr.GetAttr(path, userTags, tags, LEN(tags));

  IF res >= 0 THEN
    ttags := StringList.Create();
    CommaSeparatedToStringList(tags, ttags);
    StringList.DumpOut(ttags);
  ELSE
    Out.String("No tags found in namespace "); Out.String(userTags); Out.Ln;
  END;
END ListTags;

PROCEDURE DeleteTag(path, tag: ARRAY OF CHAR);
VAR
  tags: ARRAY 1024 OF CHAR;
  ttags: StringList.TStringList;
  res, totalLength: LONGINT;
  idx: LONGINT;
BEGIN
  res := xattr.GetAttr(path, userTags, tags, LEN(tags));
  IF res >= 0 THEN
    ttags := StringList.Create();
    CommaSeparatedToStringList(tags, ttags);

    idx := StringList.IndexOf(ttags, tag);
    IF idx >= 0 THEN
      ttags.Delete(ttags, idx);
      IF ttags.Count > 0 THEN
        StringListToCommaSeparated(ttags, tags, totalLength);
        res := xattr.SetAttr(path, userTags, tags, totalLength, 0);
        IF res < 0 THEN
          Out.String("Error updating tags after deletion"); Out.Ln;
        END;
      ELSE
        res := xattr.RemoveAttr(path, userTags);
        IF res < 0 THEN
          Out.String("Error removing tags from namespace "); Out.String(userTags); Out.Ln;
        ELSE
          Out.String("All tags removed from namespace "); Out.String(userTags); Out.Ln;
        END;
      END;
    ELSE
      Out.String("Tag '"); Out.String(tag); Out.String("' not found in namespace "); Out.String(userTags); Out.Ln;
    END;
  ELSE
    Out.String("Error fetching the contents of namespace "); Out.String(userTags); Out.Ln;
  END;
END DeleteTag;

PROCEDURE ClearTags(path: ARRAY OF CHAR);
VAR
  tmpres: LONGINT;
BEGIN
  tmpres := xattr.RemoveAttr(path, userTags);
  IF tmpres < 0 THEN
    Out.String("Error clearing tags in namespace "); Out.String(userTags); Out.Ln;
  ELSE
    Out.String("All tags removed from namespace "); Out.String(userTags); Out.Ln;
  END;
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
      ttags := StringList.Create();
      CommaSeparatedToStringList(tags, ttags);

      IF FoundTag(ttags, tag) THEN
        Out.String(fileList^[i].name); Out.Ln;
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
  tfile, ttag, tnamespace: ARRAY 256 OF CHAR;
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

  opt := opts.createOpt();
  opts.setOptName(opt, "-p");
  opts.setOptLName(opt, "--prefix");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "specify xattr namespace");
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

  (* Set namespace based on -p option *)
  IF opts.findOpt("-p", foptions) # NIL THEN
    opts.valOfOpt("-p", foptions, tnamespace);
    SetNamespace(tnamespace);
  ELSE
    SetNamespace("");
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
