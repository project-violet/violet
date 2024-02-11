// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

use std::{
    io::{copy, Read},
    path::PathBuf,
};

use sevenz_rust::{Error, SevenZArchiveEntry};

pub fn to_parent_entry_extract_fn(
    entry: &SevenZArchiveEntry,
    reader: &mut dyn Read,
    dest: &PathBuf,
) -> Result<bool, Error> {
    use std::{fs::File, io::BufWriter};

    if entry.is_directory() && !dest.exists() {
        std::fs::create_dir_all(&dest).map_err(Error::io)?;
        return Ok(true);
    }

    let path = dest;
    path.parent().and_then(|p| {
        if !p.exists() {
            std::fs::create_dir_all(p).ok()
        } else {
            None
        }
    });

    // extract to parent directory
    let file_name = path.file_name().unwrap();
    let to_path = PathBuf::from(path.parent().unwrap().parent().unwrap().join(file_name));

    let file = File::create(&to_path)
        .map_err(|e| Error::Io(e, to_path.to_string_lossy().to_string().into()))?;
    if entry.size() == 0 {
        return Ok(true);
    }

    let mut writer = BufWriter::new(file);
    copy(reader, &mut writer).map_err(Error::io)?;

    Ok(true)
}
