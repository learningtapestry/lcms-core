import React from "react";
import PropTypes from "prop-types";
import { Modal } from "bootstrap";

const MODAL_STYLES = {
  dialog: { width: "66.67vw", maxWidth: 600 },
  content: { height: 400 },
  body: { overflow: "auto", minHeight: 0 }
};

const isImageFile = (file) => file?.type?.startsWith("image/");

class DropZone extends React.Component {
  handleKeyDown = (e) => {
    const { isDisabled, onSelect } = this.props;
    if (!isDisabled && (e.key === "Enter" || e.key === " ")) {
      e.preventDefault();
      onSelect();
    }
  };

  render() {
    const {
      isDisabled,
      isDragOver,
      onSelect,
      onDragOver,
      onDragLeave,
      onDrop,
      dragDropHint,
      pasteHint,
      ariaLabel,
      uploading,
      uploadPending
    } = this.props;

    const style = {
      minHeight: 140,
      padding: 24,
      border: "2px dashed",
      borderRadius: 8,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      gap: 8,
      cursor: isDisabled ? "not-allowed" : "pointer",
      opacity: isDisabled ? 0.6 : 1,
      transition: "border-color 0.2s, background-color 0.2s",
      ...(isDragOver
        ? { borderColor: "var(--bs-primary)", backgroundColor: "rgba(var(--bs-primary-rgb), 0.08)" }
        : { borderColor: "var(--bs-border-color)", backgroundColor: "var(--bs-light)" })
    };

    return (
      <div
        role="button"
        tabIndex={isDisabled ? -1 : 0}
        className="mb-3"
        style={style}
        onDragOver={isDisabled ? undefined : onDragOver}
        onDragLeave={isDisabled ? undefined : onDragLeave}
        onDrop={isDisabled ? undefined : onDrop}
        onClick={isDisabled ? undefined : onSelect}
        onKeyDown={this.handleKeyDown}
        aria-label={ariaLabel}
        aria-disabled={isDisabled}
      >
        {uploadPending ? (
          <div className="spinner-border spinner-border-sm" role="status">
            <span className="visually-hidden">{uploading}</span>
          </div>
        ) : (
          <>
            <i className="bi bi-cloud-arrow-up fs-2 text-muted" aria-hidden="true" />
            <span className="text-muted small">{dragDropHint}</span>
            <span className="text-muted small">{pasteHint}</span>
          </>
        )}
      </div>
    );
  }
}

DropZone.propTypes = {
  isDisabled: PropTypes.bool.isRequired,
  isDragOver: PropTypes.bool.isRequired,
  onSelect: PropTypes.func.isRequired,
  onDragOver: PropTypes.func.isRequired,
  onDragLeave: PropTypes.func.isRequired,
  onDrop: PropTypes.func.isRequired,
  dragDropHint: PropTypes.string.isRequired,
  pasteHint: PropTypes.string.isRequired,
  ariaLabel: PropTypes.string.isRequired
};

class ImageUpload extends React.Component {
  constructor(props) {
    super(props);
    this.previewModalRef = React.createRef();
    this.uploadModalRef = React.createRef();
    this.fileInputRef = React.createRef();
    this.previewModalInstance = null;
    this.uploadModalInstance = null;
    this.state = {
      currentUrl: props.imageUrl || "",
      uploadPending: false,
      uploadError: null,
      uploadComplete: false,
      isDragOver: false,
      wrongFileTypeWarning: null
    };
  }

  componentDidMount() {
    if (this.previewModalRef.current) {
      this.previewModalInstance = new Modal(this.previewModalRef.current);
    }
    if (this.uploadModalRef.current) {
      this.uploadModalInstance = new Modal(this.uploadModalRef.current);
      this.uploadModalRef.current.addEventListener("show.bs.modal", this.handleUploadModalShow);
      this.uploadModalRef.current.addEventListener("shown.bs.modal", this.handleUploadModalShown);
      this.uploadModalRef.current.addEventListener("hide.bs.modal", this.handleUploadModalHide);
      this.uploadModalRef.current.addEventListener("hidden.bs.modal", this.handleUploadModalHidden);
    }
    this.syncHiddenInput();
    const form = this.getForm();
    if (form) form.addEventListener("submit", this.syncHiddenInput);
  }

  componentWillUnmount() {
    const form = this.getForm();
    if (form) form.removeEventListener("submit", this.syncHiddenInput);
    document.removeEventListener("paste", this.handlePaste);
    if (this.uploadModalRef.current) {
      this.uploadModalRef.current.removeEventListener("show.bs.modal", this.handleUploadModalShow);
      this.uploadModalRef.current.removeEventListener("shown.bs.modal", this.handleUploadModalShown);
      this.uploadModalRef.current.removeEventListener("hide.bs.modal", this.handleUploadModalHide);
      this.uploadModalRef.current.removeEventListener("hidden.bs.modal", this.handleUploadModalHidden);
    }
    this.previewModalInstance?.dispose();
    this.uploadModalInstance?.dispose();
  }

  componentDidUpdate(prevProps, prevState) {
    if (prevState.currentUrl !== this.state.currentUrl) {
      this.syncHiddenInput();
    }
  }

  getForm = () => {
    const { formId } = this.props;
    return formId ? document.getElementById(formId) : null;
  };

  syncHiddenInput = () => {
    const { formId, fieldName } = this.props;
    if (!formId || !fieldName) return;
    const input = document.querySelector(`input[form="${formId}"][name="${fieldName}"]`);
    if (input) input.value = this.state.currentUrl || "";
  };

  notifyFormChange = () => {
    const form = this.getForm();
    if (form) form.dispatchEvent(new Event("change", { bubbles: true }));
  };

  handleUploadModalShow = () => {
    this.setState({ uploadComplete: false, wrongFileTypeWarning: null, uploadError: null });
  };

  handleUploadModalShown = () => {
    document.addEventListener("paste", this.handlePaste);
  };

  handleUploadModalHide = (e) => {
    if (this.state.uploadPending) e.preventDefault();
  };

  handleUploadModalHidden = () => {
    document.removeEventListener("paste", this.handlePaste);
    this.setState({ isDragOver: false, uploadComplete: false, wrongFileTypeWarning: null });
  };

  showWrongFileTypeWarning = () => {
    const { wrongFileType } = this.props;
    this.setState({ wrongFileTypeWarning: wrongFileType });
  };

  handlePaste = (e) => {
    if (this.state.uploadComplete) return;
    const file = e.clipboardData?.files?.[0];
    if (file) {
      e.preventDefault();
      if (isImageFile(file)) {
        this.uploadFile(file);
      } else {
        this.showWrongFileTypeWarning();
      }
    }
  };

  handleFileChange = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      if (isImageFile(file)) {
        this.uploadFile(file);
      } else {
        this.showWrongFileTypeWarning();
      }
      e.target.value = "";
    }
  };

  handleDragOver = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (!this.state.uploadPending && !this.state.uploadComplete) {
      this.setState({ isDragOver: true });
    }
    e.dataTransfer.dropEffect = "copy";
  };

  handleDragLeave = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({ isDragOver: false });
  };

  handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    this.setState({ isDragOver: false });
    if (this.state.uploadPending || this.state.uploadComplete) return;
    const file = e.dataTransfer?.files?.[0];
    if (file) {
      if (isImageFile(file)) {
        this.uploadFile(file);
      } else {
        this.showWrongFileTypeWarning();
      }
    }
  };

  uploadFile = (file) => {
    const { uploadUrl, fileFieldName = "image" } = this.props;
    if (!uploadUrl) return;

    this.setState({ uploadPending: true, uploadError: null, wrongFileTypeWarning: null });

    const formData = new FormData();
    formData.append(fileFieldName, file);

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content");

    fetch(uploadUrl, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: formData
    })
      .then((response) => {
        if (!response.ok) {
          return response
            .json()
            .then((data) => { throw new Error(data.error || `Upload failed (${response.status})`); })
            .catch(() => { throw new Error(`Upload failed (${response.status})`); });
        }
        return response.json();
      })
      .then((data) => {
        this.setState({
          currentUrl: data.url,
          uploadPending: false,
          uploadError: null,
          uploadComplete: true
        });
        this.notifyFormChange();
      })
      .catch((err) => {
        this.setState({ uploadPending: false, uploadError: err.message });
      });
  };

  showFilePicker = () => this.fileInputRef.current?.click();

  showPreviewModal = () => this.previewModalInstance?.show();

  showUploadModal = () => this.uploadModalInstance?.show();

  closeUploadModal = () => this.uploadModalInstance?.hide();

  renderPreviewModal() {
    const { useResetInfo, imagePreviewTitle, close, fullSizeAlt } = this.props;
    const displayUrl = this.state.currentUrl || this.props.imageUrl;

    return (
      <div
        className="modal fade"
        ref={this.previewModalRef}
        tabIndex={-1}
        aria-labelledby="imagePreviewModalLabel"
        aria-hidden="true"
      >
        <div className="modal-dialog modal-dialog-centered" style={MODAL_STYLES.dialog}>
          <div className="modal-content" style={MODAL_STYLES.content}>
            <div className="modal-header">
              <h5 className="modal-title" id="imagePreviewModalLabel">
                {imagePreviewTitle}
              </h5>
              <button type="button" className="btn-close" data-bs-dismiss="modal" aria-label={close} />
            </div>
            <div className="modal-body text-center p-0" style={MODAL_STYLES.body}>
              <img
                src={displayUrl}
                alt={fullSizeAlt}
                className="img-fluid"
                style={{ maxWidth: "100%", margin: 24 }}
              />
              {useResetInfo && (
                <p className="text-muted small px-3" style={{ marginTop: 12, marginBottom: 12 }}>
                  <i className="bi bi-info-circle me-1" aria-hidden="true" />
                  {useResetInfo}
                </p>
              )}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" data-bs-dismiss="modal">
                {close}
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  renderUploadModal() {
    const { uploadPending, uploadError, uploadComplete, isDragOver, wrongFileTypeWarning } = this.state;
    const {
      uploadImageTitle,
      close,
      uploadSuccess,
      uploading,
      dragDropHint,
      pasteHint,
      dropZoneAriaLabel
    } = this.props;

    const isDisabled = uploadPending || uploadComplete;

    return (
      <div
        className="modal fade"
        ref={this.uploadModalRef}
        tabIndex={-1}
        aria-labelledby="uploadImageModalLabel"
        aria-hidden="true"
      >
        <div className="modal-dialog modal-dialog-centered" style={MODAL_STYLES.dialog}>
          <div className="modal-content">
            <div className="modal-header">
              <h5 className="modal-title" id="uploadImageModalLabel">
                {uploadImageTitle}
              </h5>
              <button disabled={uploadPending} type="button" className="btn-close" data-bs-dismiss="modal" aria-label={close} />
            </div>
            <div className="modal-body" style={MODAL_STYLES.body}>
              <input
                ref={this.fileInputRef}
                type="file"
                accept="image/*"
                className="d-none"
                onChange={this.handleFileChange}
                disabled={isDisabled}
                aria-hidden="true"
              />
              {uploadComplete && (
                <div className="alert alert-success mb-3" role="status">
                  <i className="bi bi-check-circle me-2" aria-hidden="true" />
                  {uploadSuccess}
                </div>
              )}
              {wrongFileTypeWarning && (
                <div className="alert alert-warning mb-3" role="alert">
                  <i className="bi bi-exclamation-triangle me-2" aria-hidden="true" />
                  {wrongFileTypeWarning}
                </div>
              )}
              {uploadError && (
                <div className="alert alert-danger mb-3" role="alert">
                  {uploadError}
                </div>
              )}
              <DropZone
                isDisabled={isDisabled}
                isDragOver={isDragOver}
                onSelect={this.showFilePicker}
                onDragOver={this.handleDragOver}
                onDragLeave={this.handleDragLeave}
                onDrop={this.handleDrop}
                dragDropHint={dragDropHint}
                pasteHint={pasteHint}
                ariaLabel={dropZoneAriaLabel}
                uploading={uploading}
                uploadPending={uploadPending}
              />
              <button
                type="button"
                className="btn btn-primary"
                data-bs-dismiss="modal"
                disabled={uploadPending}
              >
                {close}
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  render() {
    const { imageUrl, addImage, previewAlt, viewFullSize } = this.props;
    const displayUrl = this.state.currentUrl || imageUrl;

    return (
      <>
        {!displayUrl ? (
          <span
            className="text-primary"
            style={{ cursor: "pointer", textDecoration: "underline" }}
            onClick={this.showUploadModal}
            onKeyDown={(e) => e.key === "Enter" && this.showUploadModal()}
            role="button"
            tabIndex={0}
            aria-label={addImage}
          >
            {addImage}
          </span>
        ) : (
          <img
            src={displayUrl}
            alt={previewAlt}
            className="img-thumbnail"
            style={{ maxHeight: "60px", width: "auto", cursor: "pointer" }}
            onClick={this.showPreviewModal}
            onKeyDown={(e) => e.key === "Enter" && this.showPreviewModal()}
            role="button"
            tabIndex={0}
            aria-label={viewFullSize}
          />
        )}
        {this.renderPreviewModal()}
        {this.renderUploadModal()}
      </>
    );
  }
}

const I18N_DEFAULTS = {
  addImage: "Add image",
  imagePreviewTitle: "Image Preview",
  uploadImageTitle: "Upload Image",
  close: "Close",
  uploadSuccess: "Image uploaded successfully.",
  uploading: "Uploading…",
  dragDropHint: "Drag & drop image here",
  pasteHint: "or paste with Ctrl+V",
  dropZoneAriaLabel: "Drop image here or paste with Ctrl+V",
  wrongFileType: "Please select an image file (e.g. PNG, JPEG, GIF).",
  fullSizeAlt: "Full size preview",
  previewAlt: "Preview",
  viewFullSize: "Click to view full size"
};

ImageUpload.propTypes = {
  imageUrl: PropTypes.string,
  uploadUrl: PropTypes.string.isRequired,
  formId: PropTypes.string,
  fieldName: PropTypes.string,
  fileFieldName: PropTypes.string,
  useResetInfo: PropTypes.string,
  addImage: PropTypes.string,
  imagePreviewTitle: PropTypes.string,
  uploadImageTitle: PropTypes.string,
  close: PropTypes.string,
  uploadSuccess: PropTypes.string,
  uploading: PropTypes.string,
  dragDropHint: PropTypes.string,
  pasteHint: PropTypes.string,
  dropZoneAriaLabel: PropTypes.string,
  wrongFileType: PropTypes.string,
  fullSizeAlt: PropTypes.string,
  previewAlt: PropTypes.string,
  viewFullSize: PropTypes.string
};

ImageUpload.defaultProps = I18N_DEFAULTS;

export default ImageUpload;
