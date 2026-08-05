# Third-party software notices

LANImageUploader uses the following open-source dependency for local SMB
connectivity. This notice is part of the release checklist and must be included
in the public source/support materials distributed with the App Store release.

## AMSMB2

- Source: <https://github.com/amosavian/AMSMB2>
- Version: 4.0.3
- Pinned revision: `1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0`
- Swift-layer source license: MIT, as stated by the upstream project.
- The package contains `libsmb2`, which is licensed under LGPL-2.1-or-later.
- Pinned `libsmb2` submodule revision: `aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03`.
- Upstream explicitly requires dynamic linking for App Store distribution.
  The Xcode project currently links and embeds AMSMB2 dynamically.

The complete upstream texts are available in the dependency sources:

- [`AMSMB2/LICENSE`](https://github.com/amosavian/AMSMB2/blob/1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0/LICENSE)
- [`libsmb2/COPYING`](https://github.com/sahlberg/libsmb2/blob/aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03/COPYING)
- [`libsmb2/LICENCE-LGPL-2.1.txt`](https://github.com/sahlberg/libsmb2/blob/aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03/LICENCE-LGPL-2.1.txt)

Before submission, the owner should confirm that the final app/support surface
provides the required license texts and that the dynamic-linking and source/
relinkability obligations are satisfied for the shipped binary. This is a legal
release gate, not an App Store Connect metadata field.
