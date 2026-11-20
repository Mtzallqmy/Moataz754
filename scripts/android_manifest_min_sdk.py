"""Set minSdkVersion to 26 in a Godot 4.7.2 unsigned template export.

Godot's prebuilt APK uses API 24. All other manifest entries and files
are copied verbatim. The calling build script aligns and signs the result.
"""
import argparse
import struct
from zipfile import ZipFile


MANIFEST = "AndroidManifest.xml"
MIN_SDK_RESOURCE = 0x0101020C


def update_min_sdk(source: bytes) -> bytes:
    data = bytearray(source)
    kind, header_size, full_size = struct.unpack_from("<HHI", data)
    if kind != 3 or full_size != len(data):
        raise ValueError("Expected a complete binary Android XML document")

    resource_ids = ()
    changes = 0
    cursor = header_size
    while cursor < full_size:
        kind, header_size, size = struct.unpack_from("<HHI", data, cursor)
        if size < header_size or not size or cursor + size > full_size:
            raise ValueError("Invalid Android XML chunk")
        if kind == 0x0180:
            resource_ids = tuple(
                resource_id for (resource_id,) in struct.iter_unpack(
                    "<I", data[cursor + header_size:cursor + size]
                )
            )
        elif kind == 0x0102:
            extension = cursor + header_size
            offset, width, count = struct.unpack_from("<HHH", data, extension + 8)
            if width < 20 or extension + offset + width * count > cursor + size:
                raise ValueError("Invalid Android XML attributes")
            for index in range(count):
                attr = extension + offset + index * width
                resource_index = struct.unpack_from("<I", data, attr + 4)[0]
                if resource_index >= len(resource_ids) or resource_ids[resource_index] != MIN_SDK_RESOURCE:
                    continue
                raw = struct.unpack_from("<I", data, attr + 8)[0]
                current_api = struct.unpack_from("<I", data, attr + 16)[0]
                if raw != 0xFFFFFFFF or data[attr + 15] != 0x10 or current_api not in (24, 26):
                    raise ValueError(f"Unexpected minSdkVersion encoding or value: {current_api}")
                struct.pack_into("<I", data, attr + 16, 26)
                changes += 1
        cursor += size
    if changes != 1:
        raise ValueError(f"Expected one minSdkVersion, found {changes}")
    return bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("unsigned_apk")
    parser.add_argument("output_apk")
    args = parser.parse_args()
    with ZipFile(args.unsigned_apk) as source, ZipFile(args.output_apk, "w") as target:
        if source.namelist().count(MANIFEST) != 1:
            raise ValueError("Expected exactly one AndroidManifest.xml")
        for entry in source.infolist():
            contents = source.read(entry)
            target.writestr(entry, update_min_sdk(contents) if entry.filename == MANIFEST else contents)


if __name__ == "__main__":
    main()
